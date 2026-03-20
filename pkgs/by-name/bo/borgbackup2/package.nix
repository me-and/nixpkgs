{
  lib,
  stdenv,
  acl,
  fetchFromGitHub,
  lz4,
  openssl,
  python3,
  installShellFiles,
  nixosTests,
  nix-update-script,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  bashInteractive,
}:

python3.pkgs.buildPythonApplication (finalAttrs: {
  pname = "borgbackup";
  version = "2.0.0b21";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "borgbackup";
    repo = "borg";
    tag = finalAttrs.version;
    hash = "sha256-u9hXzo4OyOf6iixQhm3NEzVDb+4irkaLHH2PjnmfmM8=";
    meta.license = lib.licenses.bsd3;
  };

  patches = [
    ./findcompletions.diff

    # TODO Submit these upstream.
    ./filemode.diff
    ./createdir.diff
  ];

  # Let the Borg test suite know where to find the fish completion script.
  # TODO Is this test definitely running?  How does it know where to find
  # `fish` itself, given I haven't included it as a dependency!?
  postPatch = ''
    substituteInPlace src/borg/testsuite/shell_completions_test.py \
        --replace-fail PLACEHOLDER_OUT "$out"
  '';

  build-system = with python3.pkgs; [
    cython
    setuptools-scm
    pkgconfig
  ];

  nativeBuildInputs = [
    installShellFiles
  ]
  ++ (with python3.pkgs; [
    sphinxHook
    sphinxcontrib-jquery
    guzzle-sphinx-theme
  ]);

  sphinxBuilders = [
    "singlehtml"
    "man"
  ];

  buildInputs = [
    lz4
    openssl
  ]
  ++ lib.optional stdenv.hostPlatform.isLinux acl;

  dependencies =
    (with python3.pkgs; [
      msgpack
      packaging
      borghash
      borgstore
      platformdirs
      argon2-cffi
      shtab
      backports-zstd
      xxhash
      jsonargparse
      pyyaml
    ])
    # Provide all the optional extras, since they don't make much difference to
    # closure size and users might be expecting them.  But only one of the fuse
    # interfaces, because more than that would be excessive.
    ++ lib.concatAttrValues (
      builtins.removeAttrs finalAttrs.passthru.optional-dependencies [
        "llfuse"
        "mfusepy"
      ]
    );

  optional-dependencies = with python3.pkgs; {
    llfuse = [ llfuse ];
    pyfuse3 = [ pyfuse3 ];
    mfusepy = [ mfusepy ];
    s3 = borgstore.optional-dependencies.s3;
    sftp = borgstore.optional-dependencies.sftp;
    rclone = borgstore.optional-dependencies.rclone;
    rest = borgstore.optional-dependencies.rest;
    cockpit = [ textual ];
  };

  # TODO What's best practice for making the package available with some or all
  # of these?  Just listing them here seems to be the preferred approach for
  # Python modules, but what about applications that just happen to be written
  # in Python?  Borg can clearly run without all of these, but I expect at
  # least some of them are desirable for a lot of people so should be included
  # in one of the standard packaging options.
  optional-dependencies = with python3.pkgs; {
    llfuse = [ llfuse ];
    pyfuse3 = [ pyfuse3 ];
    mfusepy = [ mfusepy ];
    s3 = borgstore.optional-dependencies.s3;
    sftp = borgstore.optional-dependencies.sftp;
    rclone = borgstore.optional-dependencies.rclone;
    rest = borgstore.optional-dependencies.rest;
    cockpit = [ textual ];
  };

  preInstallSphinx = ''
    # Remove invalid outputs for manpages
    rm .sphinx/man/man/_static/jquery.js
    rm .sphinx/man/man/_static/_sphinx_javascript_frameworks_compat.js
    rmdir .sphinx/man/man/_static/
  '';

  postInstall = ''
    installShellCompletion --cmd borg --fish scripts/shell_completions/fish/borg.fish
  '';

  nativeCheckInputs =
    with python3.pkgs;
    [
      pytest-benchmark
      pytest-xdist
      pytestCheckHook
      versionCheckHook
      writableTmpDirAsHomeHook
    ]
    ++ lib.concatAttrValues finalAttrs.passthru.optional-dependencies;

  preCheck =
    # Tests require a writable runtime directory, so create one.
    ''
      XDG_RUNTIME_DIR="$(mktemp -d)"
      export XDG_RUNTIME_DIR
    ''
    # Bash completion tests need interactive Bash in the PATH.  Explicitly
    # prepend it, as otherwise the non-interactive version in stdenv takes
    # priority.
    #
    # Also need to have the borg executable in PATH, as the tests expect to
    # find it there.
    + ''
      export PATH=${bashInteractive}/bin:"$out"/bin"''${PATH:+:$PATH}"
    '';

  pytestFlags = [
    "--benchmark-skip"
    "--pyargs"
    "borg.testsuite"
  ];

  disabledTests = [
    # FUSE tests require /dev/fuse and fusermount/umount, which aren't
    # available in the Nix sandbox.
    "test_fuse"
    "test_fuse_allow_damaged_files"
    "test_fuse_duplicate_name"
    "test_fuse_mount_hardlinks"
    "test_fuse_mount_options"
    "test_fuse_versions_view"
    "test_migrate_lock_alive"
  ];

  # TODO Override these tests to run with this version of borgbackup.
  passthru.tests = {
    inherit (nixosTests) borgbackup;
  };

  outputs = [
    "out"
    "doc"
    "man"
  ];

  passthru.updateScript = nix-update-script {
    # Only match tags that start with "2."
    extraArgs = [
      "--version-regex"
      "^(2\\..*)$"
    ];
  };

  meta = {
    inherit (finalAttrs.src.meta) license;
    changelog = "https://github.com/borgbackup/borg/blob/${finalAttrs.src.rev}/docs/changes.rst";
    description = "Beta deduplicating archiver with compression and encryption";
    homepage = "https://www.borgbackup.org";
    platforms = lib.platforms.unix;
    mainProgram = "borg";
    maintainers = [ lib.maintainer.me-and ];
  };
})
