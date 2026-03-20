{
  lib,
  buildPythonPackage,
  setuptools-scm,
  requests,
  paramiko,
  boto3,
  fetchFromGitHub,
  pytestCheckHook,
  pytest-xdist,
}:
buildPythonPackage (finalAttrs: {
  pname = "borgstore";
  version = "0.4.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "borgbackup";
    repo = "borgstore";
    tag = finalAttrs.version;
    hash = "sha256-Cm5Gi2zzc5YT51mOzT4fQUNqds2iniFgntu9GHURjf4=";
    meta.license = lib.licenses.bsd3;
  };

  build-system = [ setuptools-scm ];

  optional-dependencies = {
    rest = [ requests ];
    rclone = [ requests ];
    sftp = [ paramiko ];
    s3 = [ boto3 ];
  };

  nativeCheckInputs = [
    pytest-xdist
    pytestCheckHook
  ]
  ++ lib.concatAttrValues finalAttrs.passthru.optional-dependencies;

  meta = {
    inherit (finalAttrs.src.meta) homepage license;
    description = "Experimental Borg Backup storage backend";
    maintainers = [ lib.maintainer.me-and ];
  };
})
