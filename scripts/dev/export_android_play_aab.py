#!/usr/bin/env python3
"""Export the unified Play AAB with its permanent upload key; never upload it."""

import argparse
import base64
import configparser
import ctypes
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[2]
KEYSTORE = Path.home() / "Library/Application Support/Swarmfront/signing/android/swarmfront-play-upload.keystore"
ALIAS = "swarmfront-play-upload"
KEYCHAIN_SERVICE = "com.entap.swarmfront.android.play.upload"
KEYCHAIN_ACCOUNT = "swarmfront-play-upload"
CERT_SHA256 = "c75c4e8c5e845379e876ba791d0e1bb931f1e552026b39464bda93b661d02a35"
PACKAGE = "com.entap.swarmfront"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def verify_preset():
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.read(ROOT / "export_presets.cfg")
    sections = [s for s in config.sections() if config[s].get("name") == '"Android"']
    require(len(sections) == 1, "Exactly one Android release preset is required.")
    preset = config[sections[0]]
    options = config[sections[0] + ".options"]
    require(preset.get("platform") == '"Android"', "Wrong export platform.")
    require(preset.get("custom_features") == '"store_release"', "Store release safeguards are required.")
    require(options.get("package/unique_name") == '"' + PACKAGE + '"', "Wrong Android application ID.")
    require(options.get("gradle_build/export_format") == "1", "Play export must be an AAB.")
    require(options.get("package/signed") == "false", "Godot must leave signing to the secure AAB launcher.")
    for key in ["keystore/release", "keystore/release_user", "keystore/release_password"]:
        require(options.get(key, '""') == '""', "Signing material must be supplied only by this launcher.")


def keychain_password():
    # Read in-process through the same native API used when creating the item.
    # No password is printed or passed through a shell or security CLI process.
    security = ctypes.CDLL("/System/Library/Frameworks/Security.framework/Security")
    find = security.SecKeychainFindGenericPassword
    find.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_char_p,
                     ctypes.c_uint32, ctypes.c_char_p, ctypes.POINTER(ctypes.c_uint32),
                     ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p]
    find.restype = ctypes.c_int32
    free = security.SecKeychainItemFreeContent
    free.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    free.restype = ctypes.c_int32
    service, account = KEYCHAIN_SERVICE.encode(), KEYCHAIN_ACCOUNT.encode()
    size, data = ctypes.c_uint32(), ctypes.c_void_p()
    status = find(None, len(service), service, len(account), account,
                  ctypes.byref(size), ctypes.byref(data), None)
    require(status == 0, "Unable to retrieve the Play upload password from macOS Keychain.")
    try:
        password = ctypes.string_at(data, size.value).decode("utf-8")
    finally:
        free(None, data)
    require(bool(password), "The Play upload Keychain password is empty.")
    return password


def signing_environment(java_home):
    require(KEYSTORE.is_file(), "The permanent Play upload keystore is missing.")
    require(not KEYSTORE.resolve().is_relative_to(ROOT), "The keystore must be outside source.")
    password = keychain_password()
    env = os.environ.copy()
    # Always replace inherited RC signing values. The password never enters argv.
    env.update({
        "JAVA_HOME": str(java_home),
        "GODOT_ANDROID_KEYSTORE_RELEASE_PATH": str(KEYSTORE),
        "GODOT_ANDROID_KEYSTORE_RELEASE_USER": ALIAS,
        "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD": password,
    })
    certificate = subprocess.run(
        [str(java_home / "bin/keytool"), "-exportcert", "-keystore", str(KEYSTORE),
         "-alias", ALIAS, "-storepass:env", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"],
        env=env, capture_output=True, check=False,
    )
    require(certificate.returncode == 0, "Unable to unlock the permanent Play upload key.")
    require(hashlib.sha256(certificate.stdout).hexdigest() == CERT_SHA256,
            "Play upload certificate mismatch; refusing to sign with a different key.")
    return env


def verify_game_payload(bundle):
    # Godot can return success after a resource-save error interrupts packaging.
    # Its final project settings and script cache must actually be in the AAB.
    with zipfile.ZipFile(bundle) as archive:
        configs = [name for name in archive.namelist() if name.endswith("/assets/project.binary")]
        require(len(configs) == 1, "AAB has no unique project.binary; resource export is incomplete.")
        prefix = configs[0][:-len("project.binary")]
        config = archive.read(configs[0])
        require(config.startswith(b"ECFG") and b"store_release" in config,
                "AAB project settings are invalid or lack store safeguards.")
        for resource in [".godot/global_script_class_cache.cfg", ".godot/uid_cache.bin",
                         "scripts/ui/main_menu.gdc", "scripts/state/account_deletion_runtime.gdc",
                         "scripts/state/player_identity_runtime.gdc",
                         "scripts/platform/native_secure_credential_store.gdc"]:
            require(prefix + resource in archive.namelist() and bool(archive.read(prefix + resource)),
                    "AAB is missing required runtime content: " + resource)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-signing", action="store_true", help="Verify configuration and Keychain without building.")
    parser.add_argument("--output", type=Path, help="New .aab path outside the source worktree.")
    args = parser.parse_args()
    verify_preset()
    java_home = Path(os.environ.get("JAVA_HOME", "/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"))
    require((java_home / "bin/keytool").is_file(), "JDK 17 keytool is required; set JAVA_HOME.")
    if args.check_signing:
        signing_environment(java_home)
        print("PLAY_UPLOAD_SIGNING_CHECK: PASS (new permanent key; no build or upload)")
        print("Certificate SHA-256: " + CERT_SHA256)
        return

    require(args.output is not None, "Specify --output with an external .aab path.")
    output = args.output.expanduser().resolve()
    require(output.suffix.lower() == ".aab" and not output.is_relative_to(ROOT),
            "The AAB output must be outside the source worktree.")
    require(not output.exists(), "Refusing to overwrite an existing release artifact.")
    status = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, check=True)
    require(not status.stdout, "Commit the unified candidate before building store artifacts.")
    source_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    print("PLAY_AAB_SOURCE_COMMIT: " + source_commit, flush=True)
    default_godot = Path.home() / "Library/Application Support/Swarmfront/toolchains/godot/4.7.1/Godot.app/Contents/MacOS/Godot"
    godot = os.environ.get("GODOT_BIN", str(default_godot))
    version = subprocess.run([godot, "--version"], capture_output=True, text=True, check=True)
    require(version.stdout.strip() == "4.7.1.stable.official.a13da4feb", "The pinned Godot 4.7.1 runtime is required.")
    gate_env = os.environ.copy()
    gate_env["GODOT_BIN"] = godot
    # The canonical gate is mandatory; signing credentials are fetched afterwards.
    for key in ["GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"]:
        gate_env.pop(key, None)
    subprocess.run(["bash", "scripts/dev/run_release_readiness_gate.sh", "--matrix-gate", "pr",
                    "--include-tf-preflight"], cwd=ROOT, env=gate_env, check=True)
    require(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == source_commit
            and not subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT),
            "Source changed during preflight; refusing to build.")
    env = signing_environment(java_home)
    output.parent.mkdir(parents=True, exist_ok=True)
    # Godot's Gradle signer places its password in process arguments. Export a
    # temporary unsigned bundle, then sign with jarsigner's environment options.
    # Only the signed result is published at the requested artifact path.
    with tempfile.TemporaryDirectory(prefix=".play-aab-", dir=output.parent) as tempdir:
        unsigned = Path(tempdir) / "unsigned.aab"
        export_env = env.copy()
        for key in ["GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"]:
            export_env.pop(key, None)
        subprocess.run([godot, "--headless", "--path", str(ROOT), "--install-android-build-template",
                        "--export-release", "Android", str(unsigned)],
                       env=export_env, check=True)
        require(unsigned.is_file(), "Android AAB export failed.")
        verify_game_payload(unsigned)
        require(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == source_commit
                and not subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT),
                "Source changed during export; refusing to sign.")
        signed = subprocess.run(
            [str(java_home / "bin/jarsigner"), "-keystore", str(KEYSTORE),
             "-storepass:env", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD",
             "-keypass:env", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD",
             "-sigalg", "SHA384withRSA", "-digestalg", "SHA-256",
             "-signedjar", str(output), str(unsigned), ALIAS],
            env=env, capture_output=True, check=False,
        )
        require(signed.returncode == 0 and output.is_file(), "Signing the Play AAB failed.")
    certificate = subprocess.run([str(java_home / "bin/keytool"), "-printcert", "-rfc", "-jarfile", str(output)],
                                 capture_output=True, check=True)
    pem = re.search(rb"-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----", certificate.stdout, re.S)
    require(pem is not None and hashlib.sha256(base64.b64decode(pem.group(1))).hexdigest() == CERT_SHA256,
            "Exported AAB does not contain the permanent Play upload certificate.")
    verification = subprocess.run([str(java_home / "bin/jarsigner"), "-verify", str(output)], capture_output=True, check=False)
    require(verification.returncode == 0 and b"jar verified." in verification.stdout, "AAB signature verification failed.")
    print("PLAY_AAB_SIGNED: " + str(output))
    print("Certificate SHA-256: " + CERT_SHA256)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        # Do not echo subprocess output, environment values or credential-bearing errors.
        print("PLAY_AAB_FAIL: " + (str(error) if isinstance(error, RuntimeError) else type(error).__name__), file=sys.stderr)
        sys.exit(1)
