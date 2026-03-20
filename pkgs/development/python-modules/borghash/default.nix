{
  lib,
  buildPythonPackage,
  cython,
  setuptools-scm,
  pkgconfig,
  fetchFromGitHub,
  pytest-benchmark,
  pytest-xdist,
  pytestCheckHook,
}:
buildPythonPackage (finalAttrs: {
  pname = "borghash";
  version = "0.1.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "borgbackup";
    repo = "borghash";
    tag = finalAttrs.version;
    hash = "sha256-aJplDFMHoDzTOD/8Z9OGhWDvKapXJ5kiho/3b4aCwa4=";
    meta.license = lib.licenses.bsd3;
  };

  build-system = [
    cython
    setuptools-scm
    pkgconfig
  ];

  nativeCheckInputs = [
    pytest-benchmark
    pytest-xdist
    pytestCheckHook
  ];

  pytestFlags = [ "--benchmark-skip" ];

  meta = {
    inherit (finalAttrs.src.meta) homepage license;
    description = "Memory-efficient hashtable with serialization";
    maintainers = [ lib.maintainer.me-and ];
  };
})
