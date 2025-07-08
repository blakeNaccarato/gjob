"""Tests."""

from os import environ

import pytest
from gjob_pipeline.stages.convert import Convert as Params
from gjob_pipeline.stages.convert.__main__ import main


def test_import():
    """Trivial test that the package is importable."""
    import gjob  # noqa: F401, PLC0415


@pytest.mark.skipif(bool(environ.get("CI")), reason="No example test data yet.")
@pytest.mark.slow
def test_convert():
    main(Params())
