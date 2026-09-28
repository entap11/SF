import copy
import gzip
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from beta_game_report import build_report, review_flags, markdown


def fixture():
    return {'schema_version': 1, 'capture_id': 'a' * 32, 'owner_key': 'b' * 64,
        'build': 'test', 'source_sha256': 'c' * 64, 'status': 'completed', 'winner_seat': 1,
        'sim_ms': 60000, 'metadata': {'map_id': 'test_map', 'map_sha256': 'd' * 64, 'mode': '1V1', 'local_seat': 1},
        'players': [{'seat': 1, 'is_local': True, 'is_cpu': False}, {'seat': 2, 'is_cpu': True}],
        'profiles': [{'seat': 2, 'style': 'balancer', 'tier': 'medium', 'policy': 'human_balancer_v3'}],
        'events': [], 'frames': [{'t': t, 'h': [[1, 1, 10], [2, 2, 10]], 'l': []} for t in range(0, 60001, 500)],
        'dropped_events': 0, 'frame_stride': 1}


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.folder = Path(self.temp.name)
        (self.folder / 'recordings').mkdir()
        self.rows = []

    def tearDown(self):
        self.temp.cleanup()

    def add(self, game=None, cohort='unknown', feedback=None):
        game = copy.deepcopy(game or fixture())
        id_ = str(len(self.rows) + 1)
        game['capture_id'] = id_.zfill(32)
        packed = gzip.compress(json.dumps(game).encode())
        (self.folder / 'recordings' / (id_ + '.json.gz')).write_bytes(packed)
        row = {'id': id_, 'capture_id': game['capture_id'], 'participant_key': game['owner_key'],
            'sha256': hashlib.sha256(packed).hexdigest(), 'cohort': cohort, 'feedback': feedback}
        self.rows.append(row)
        (self.folder / 'index.json').write_text(json.dumps(self.rows))
        return row

    def test_owner_unknown_and_controls_denominators(self):
        answers = {'experience': 'new', 'challenge': 'about_right', 'interesting': 'yes', 'controls': 'no'}
        owner = self.add(cohort='owner', feedback=answers)
        self.add(feedback=answers)
        self.add(feedback={**answers, 'controls': 'yes'})
        self.add(feedback={**answers, 'controls': 'unsure'})
        self.add()
        annotations = {owner['id']: {'capture_id': owner['capture_id'], 'control_affected': True}}
        report = build_report(self.folder, annotations)
        groups = {g['cohort']: g for g in report['groups']}
        self.assertEqual(groups['owner']['recordings'], 1)
        self.assertEqual(groups['owner']['clean_games'], 0)
        self.assertIsNone(groups['owner']['clean_human_win_pct'])
        self.assertEqual(groups['new']['recordings'], 3)
        self.assertEqual(groups['new']['clean_games'], 1)
        self.assertEqual(groups['new']['control_affected'], 1)
        self.assertEqual(groups['new']['controls_unknown'], 1)
        self.assertEqual(groups['new']['participants'], 1, 'repeat games are not extra players')
        self.assertEqual(groups['unknown']['feedback_responses'], 0)
        self.assertEqual(groups['unknown']['clean_games'], 0)
        self.assertIn('Missing/unsure answers stay unknown', markdown(report))

    def test_version_map_seat_and_lineup_are_separate(self):
        self.add()
        for change in ('build', 'map', 'seat', 'policy'):
            game = fixture()
            if change == 'build': game['source_sha256'] = 'e' * 64
            if change == 'map': game['metadata']['map_sha256'] = 'f' * 64
            if change == 'seat': game['metadata']['local_seat'] = 2
            if change == 'policy': game['profiles'][0]['policy'] = 'other'
            self.add(game)
        self.assertEqual(len(build_report(self.folder)['groups']), 5)

    def test_multiplayer_not_silently_a_bot_win_rate(self):
        game = fixture()
        game['players'].append({'seat': 3, 'is_cpu': False})
        self.add(game, feedback={'experience': 'experienced', 'controls': 'no'})
        self.assertEqual(build_report(self.folder)['groups'][0]['clean_games'], 0)

    def test_digest_and_annotation_identity(self):
        row = self.add()
        with self.assertRaises(ValueError):
            build_report(self.folder, {'1': {'capture_id': 'wrong'}})
        file = self.folder / 'recordings/1.json.gz'
        file.write_bytes(file.read_bytes() + b'x')
        with self.assertRaises(ValueError): build_report(self.folder)

    def test_persistent_routes_are_not_reported_as_no_routes(self):
        game = fixture()
        for frame in game['frames']: frame['l'] = [[1, 2, 1, 1, 0, 1.0]]
        flags = review_flags(game)
        self.assertIn('long_order_gap', [f['kind'] for f in flags])
        self.assertNotIn('no_observed_outgoing_routes', [f['kind'] for f in flags])
        game['frames'] = [dict(f, l=[]) for f in game['frames']]
        self.assertIn('no_observed_outgoing_routes', [f['kind'] for f in review_flags(game)])

    def test_repeated_pressure_differs_from_defending_owned_target(self):
        game = fixture()
        game['events'] = [{'e': 9, 't': t, 'p': 2, 'src': 2, 'dst': 1, 'intent': 'swarm', 'ok': True} for t in (1000, 7000, 14000)]
        self.assertIn('repeated_pressure_without_sampled_gain', [f['kind'] for f in review_flags(game)])
        for frame in game['frames']: frame['h'][0][1] = 2
        self.assertNotIn('repeated_pressure_without_sampled_gain', [f['kind'] for f in review_flags(game)])
        for event in game['events']: event['ok'] = False
        self.assertIn('repeated_rejected_order', [f['kind'] for f in review_flags(game)])

    def test_eliminated_bot_does_not_get_endgame_idle_flag(self):
        game = fixture()
        for frame in game['frames']:
            if frame['t'] >= 5000: frame['h'][1][1] = 1
        self.assertEqual(review_flags(game), [])

    def test_incomplete_coverage_does_not_become_false_inactivity(self):
        game = fixture()
        game['dropped_events'] = 100
        self.assertEqual([f['kind'] for f in review_flags(game)], ['reduced_coverage'])
        game['dropped_events'] = 0
        game['frame_stride'] = 2
        self.assertEqual([f['kind'] for f in review_flags(game)], ['reduced_coverage'])


if __name__ == '__main__': unittest.main()
