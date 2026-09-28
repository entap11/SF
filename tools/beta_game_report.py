#!/usr/bin/env python3
"""Build private beta review reports from verified archive exports; never tune bots."""
import argparse
from collections import Counter, defaultdict
import gzip
import hashlib
import json
from pathlib import Path
import statistics

ORDER_GAP_MS = 30000
REPEAT_WINDOW_MS = 30000
REPEAT_COUNT = 3
EMPTY_HASH = hashlib.sha256(b'').hexdigest()


def review_flags(game):
    """Heuristics are review cues, with explicit windows; they do not prove defects."""
    flags = []
    frames = sorted(game.get('frames', []), key=lambda f: f['t'])
    events = game.get('events', [])
    intents = [e for e in events if e.get('e') == 9]
    if game.get('dropped_events', 0) or game.get('frame_stride', 1) != 1:
        flags.append({'kind': 'reduced_coverage', 'dropped_events': game.get('dropped_events', 0), 'frame_stride': game.get('frame_stride', 1)})
        # Do not turn evidence omitted by capture bounds into a behavioral finding.
        return flags
    for player in game.get('players', []):
        if not player.get('is_cpu'):
            continue
        seat = player['seat']
        orders = sorted([e for e in intents if e.get('p') == seat], key=lambda e: e['t'])
        alive = [f for f in frames if any(h[1] == seat for h in f.get('h', []))]
        if not alive:
            continue
        start, end = alive[0]['t'], alive[-1]['t']
        accepted = [e for e in orders if e.get('ok') is True and start <= e['t'] <= end]
        # Persistent lanes continue acting without new orders: report a gap, not "idle bot".
        ticks = [start] + [e['t'] for e in accepted] + [end]
        if ticks:
            a, b = max(zip(ticks, ticks[1:]), key=lambda pair: pair[1] - pair[0])
            if b - a >= ORDER_GAP_MS:
                flags.append({'kind': 'long_order_gap', 'seat': seat, 'from_ms': a, 'to_ms': b,
                              'note': 'Existing routes may still be productive.'})
        quiet_start = None
        quiet_end = None
        longest = (0, 0)
        for frame in frames:
            owners = {h[0]: h[1] for h in frame.get('h', [])}
            outgoing = any((lane[3] and owners.get(lane[1]) == seat) or
                           (lane[4] and owners.get(lane[2]) == seat) for lane in frame.get('l', []) if len(lane) >= 5)
            has_order = any(e.get('ok') is True and (quiet_end if quiet_end is not None else frame['t']) < e['t'] <= frame['t'] for e in orders)
            if seat in owners.values() and not outgoing:
                if quiet_start is None or has_order:
                    quiet_start = frame['t']
                quiet_end = frame['t']
                if quiet_end - quiet_start > longest[1] - longest[0]:
                    longest = (quiet_start, quiet_end)
            else:
                quiet_start = quiet_end = None
        if longest[1] - longest[0] >= ORDER_GAP_MS:
            flags.append({'kind': 'no_observed_outgoing_routes', 'seat': seat, 'from_ms': longest[0], 'to_ms': longest[1],
                          'note': 'Board samples omit travelling units; inspect the game.'})
        seen = set()
        for index, event in enumerate(orders):
            key = (event.get('intent'), event.get('src'), event.get('dst'), event.get('ok'))
            window = [e for e in orders[:index + 1] if event['t'] - REPEAT_WINDOW_MS <= e['t'] <= event['t'] and
                      (e.get('intent'), e.get('src'), e.get('dst'), e.get('ok')) == key]
            if len(window) < REPEAT_COUNT:
                continue
            if event.get('ok') is False:
                kind = 'repeated_rejected_order'
            elif event.get('ok') is True and event.get('intent') in ('attack', 'swarm'):
                target = event.get('dst')
                samples = [(f['t'], next((h for h in f.get('h', []) if h[0] == target), None))
                           for f in frames if window[0]['t'] <= f['t'] <= event['t']]
                samples = [(t, h) for t, h in samples if h is not None]
                if len(samples) < 2 or any(h[1] == seat for _, h in samples) or samples[-1][1][2] < samples[0][1][2]:
                    continue
                kind = 'repeated_pressure_without_sampled_gain'
            else:
                continue
            signature = (kind, key)
            if signature in seen:
                continue
            seen.add(signature)
            flags.append({'kind': kind, 'seat': seat, 'src': event.get('src'), 'dst': event.get('dst'),
                          'intent': event.get('intent'), 'count': len(window), 'from_ms': window[0]['t'], 'to_ms': event['t'],
                          'note': 'Review cue; combat and recovery can justify repetition.'})
    return flags


def build_report(folder, annotations=None, manifest=None):
    folder = Path(folder)
    rows = json.loads((folder / 'index.json').read_text())
    if annotations is None:
        file = folder / 'annotations.json'
        annotations = json.loads(file.read_text()) if file.exists() else {}
    groups = defaultdict(list)
    recordings = []
    for row in rows:
        archive_id = str(row['id'])
        if not archive_id.isdecimal():
            raise ValueError('invalid archive id')
        packed = (folder / 'recordings' / (archive_id + '.json.gz')).read_bytes()
        if hashlib.sha256(packed).hexdigest() != row['sha256']:
            raise ValueError('recording digest mismatch: ' + archive_id)
        game = json.loads(gzip.decompress(packed))
        if game['capture_id'] != row['capture_id'] or game['owner_key'] != row['participant_key']:
            raise ValueError('recording identity mismatch: ' + archive_id)
        annotation = annotations.get(archive_id, {})
        if annotation and annotation.get('capture_id') != row['capture_id']:
            raise ValueError('annotation belongs to another recording: ' + archive_id)
        feedback = row.get('feedback') or {}
        operator = row.get('cohort', 'unknown')
        experience = feedback.get('experience', 'unknown')
        cohort = operator if operator in ('owner', 'new', 'intermediate', 'experienced') else experience
        if cohort not in ('owner', 'new', 'intermediate', 'experienced'):
            cohort = 'unknown'
        controls = feedback.get('controls', 'unanswered')
        affected = controls == 'yes' or annotation.get('control_affected') is True
        profiles = sorted(game.get('profiles', []), key=lambda p: p.get('seat', 0))
        lineup = ' + '.join(f"{p.get('style', 'unknown')}:{p.get('tier', 'unknown')}:{p.get('policy', 'unknown')}@{p.get('seat')}" for p in profiles) or 'no_bot_profile'
        meta = game['metadata']
        map_hash = meta.get('map_sha256', '')
        map_source = 'recorded' if map_hash else 'unverified'
        if not map_hash and manifest and manifest.get('source_sha256') == game['source_sha256']:
            candidates = [digest for path, digest in manifest.get('files', {}).items()
                          if path.startswith('maps/') and Path(path).name == meta.get('map_id', '') + '.json']
            if len(candidates) == 1:
                map_hash, map_source = candidates[0], 'source_manifest'
        local_seat = meta.get('local_seat')
        players = game.get('players', [])
        single_bot = len(players) == 2 and len(profiles) == 1 and sum(bool(p.get('is_cpu')) for p in players) == 1 and any(
            p.get('seat') == local_seat and p.get('is_local') and not p.get('is_cpu') for p in players)
        completed = game['status'] == 'completed'
        clean = completed and single_bot and controls == 'no' and not affected
        flags = review_flags(game)
        if affected:
            flags.insert(0, {'kind': 'control_affected', 'source': 'player_feedback' if controls == 'yes' else 'review_annotation'})
        if not map_hash:
            flags.append({'kind': 'map_identity_unverified'})
        summary = {'archive_id': archive_id, 'capture_id': row['capture_id'], 'cohort': cohort,
            'experience_source': 'operator' if operator != 'unknown' else ('self_report' if experience != 'unknown' else 'unknown'),
            'build': game['build'], 'source_sha256': game['source_sha256'], 'map_id': meta.get('map_id', ''),
            'map_sha256': map_hash, 'map_identity_source': map_source, 'mode': meta.get('mode', ''),
            'local_seat': local_seat, 'bot_lineup': lineup, 'status': game['status'],
            'duration_seconds': game['sim_ms'] / 1000, 'winner_seat': game['winner_seat'],
            'single_bot_game': single_bot, 'human_won': completed and game['winner_seat'] == local_seat,
            'feedback': feedback or None, 'controls': controls, 'control_affected': affected,
            'clean_comparison_eligible': clean, 'flags': flags}
        recordings.append(summary)
        key = (cohort, game['build'], game['source_sha256'], meta.get('map_id', ''), map_hash, meta.get('mode', ''), local_seat, lineup)
        groups[key].append((summary, row['participant_key']))
    grouped = []
    for key, entries in sorted(groups.items(), key=lambda pair: tuple(str(v) for v in pair[0])):
        games = [item for item, _ in entries]
        completed = [g for g in games if g['status'] == 'completed']
        clean = [g for g in games if g['clean_comparison_eligible']]
        replies = [g['feedback'] for g in games if g['feedback']]
        grouped.append({'cohort': key[0], 'build': key[1], 'source_sha256': key[2], 'map_id': key[3],
            'map_sha256': key[4], 'mode': key[5], 'local_seat': key[6], 'bot_lineup': key[7],
            'recordings': len(games), 'participants': len({p for _, p in entries}), 'completed': len(completed),
            'feedback_responses': len(replies), 'control_affected': sum(g['control_affected'] for g in games),
            'controls_unknown': sum(g['controls'] in ('unanswered', 'unsure') and not g['control_affected'] for g in games),
            'raw_median_seconds': statistics.median(g['duration_seconds'] for g in completed) if completed else None,
            'clean_games': len(clean), 'clean_human_wins': sum(g['human_won'] for g in clean),
            'clean_human_win_pct': round(100 * sum(g['human_won'] for g in clean) / len(clean), 1) if clean else None,
            'clean_median_seconds': statistics.median(g['duration_seconds'] for g in clean) if clean else None,
            'clean_answers': {k: dict(Counter(g['feedback'][k] for g in clean if k in g['feedback'])) for k in ('challenge', 'interesting', 'controls')},
            'answers': {k: dict(Counter(r[k] for r in replies if k in r)) for k in ('challenge', 'interesting', 'controls')},
            'flag_counts': dict(Counter(flag['kind'] for g in games for flag in g['flags']))})
    return {'schema_version': 1, 'recordings': len(recordings), 'groups': grouped, 'games': recordings,
        'rules': {'owner_separate': True, 'clean_requires_explicit_no_control_problem': True,
            'counts_are_participant_recordings': True, 'order_gap_ms': ORDER_GAP_MS,
            'repeat_window_ms': REPEAT_WINDOW_MS, 'repeat_count': REPEAT_COUNT,
            'flags_are_review_cues_not_defects': True}}


def markdown(report):
    lines = ['# Beta game review', '', f"{report['recordings']} participant recordings. Owner results remain separate; multiplayer recordings are not unique-match counts.", '',
        'Clean comparisons require a completed one-human/one-bot game and an explicit “No” to control problems, with no contrary review annotation. Missing/unsure answers stay unknown. Raw durations remain unchanged.', '',
        '| Experience | Bot lineup | Build / map / seat | Players | Games / completed | Feedback | Controls affected / unknown | Clean games / human wins | Clean median |',
        '| --- | --- | --- | --- | --- | --- | --- | --- | --- |']
    def esc(value):
        return str(value).replace('|', '\\|').replace('\n', ' ')
    for g in report['groups']:
        median = f"{g['clean_median_seconds']:.1f}s" if g['clean_median_seconds'] is not None else '—'
        lines.append('| ' + ' | '.join(map(esc, [g['cohort'], g['bot_lineup'],
            f"{g['build']} / {g['map_id']} / {g['local_seat']}", g['participants'],
            f"{g['recordings']} / {g['completed']}", g['feedback_responses'],
            f"{g['control_affected']} / {g['controls_unknown']}", f"{g['clean_games']} / {g['clean_human_wins']}", median])) + ' |')
    for g in report['groups']:
        lines += ['', f"## {g['cohort']} · {g['bot_lineup']} · {g['build']} · {g['map_id']}", '',
            f"Source: `{g['source_sha256']}`; map: `{g['map_sha256'] or 'unverified'}`; mode: {g['mode']}; local seat: {g['local_seat']}.",
            f"Feedback: {g['feedback_responses']} of {g['recordings']} recordings from {g['participants']} player(s). Counts are answers, not inferred sentiment."]
        lines.append('')
        for field in ('challenge', 'interesting', 'controls'):
            lines.append(f"- {field.capitalize()} (all replies): " + (', '.join(f'{k}={v}' for k,v in sorted(g['answers'][field].items())) or 'unanswered'))
        lines.append('')
        lines.append('Clean challenge replies: ' + (', '.join(f'{k}={v}' for k,v in sorted(g['clean_answers']['challenge'].items())) or 'none'))
    lines += ['', '## Review queue', '', 'Flags identify evidence to inspect. Long gaps can coexist with productive routes; repeated pressure can be purposeful. Samples omit travelling units. These flags must not automatically change difficulty.', '']
    for game in report['games']:
        if not game['flags']:
            continue
        lines.append(f"- Recording {game['archive_id']} ({game['cohort']}, {game['bot_lineup']}, {game['duration_seconds']:.1f}s raw):")
        for flag in game['flags']:
            window = f" at {flag['from_ms']/1000:.1f}–{flag['to_ms']/1000:.1f}s" if 'from_ms' in flag else ''
            lines.append(f"  - {flag['kind']}{window}. {flag.get('note', '')}".rstrip())
    if not any(g['flags'] for g in report['games']):
        lines.append('No configured review flags. This is not proof that controls or bots were fault-free.')
    return '\n'.join(lines) + '\n'


def write_report(folder, annotations=None, manifest=None):
    report = build_report(folder, annotations, manifest)
    folder = Path(folder)
    for name, value in [('report.json', json.dumps(report, indent=2) + '\n'), ('report.md', markdown(report))]:
        temp = folder / (name + '.tmp')
        temp.write_text(value)
        temp.replace(folder / name)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--annotations', type=Path)
    parser.add_argument('--manifest', type=Path)
    args = parser.parse_args()
    annotations = json.loads(args.annotations.read_text()) if args.annotations else None
    manifest = json.loads(args.manifest.read_text()) if args.manifest else None
    report = write_report(args.archive, annotations, manifest)
    print(json.dumps({'recordings': report['recordings'], 'groups': len(report['groups']), 'report': str(args.archive / 'report.md')}))


if __name__ == '__main__':
    main()
