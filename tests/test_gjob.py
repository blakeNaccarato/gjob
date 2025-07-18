"""Tests."""

from os import environ

import pytest
from gjob_pipeline.stages.convert import Convert
from gjob_pipeline.stages.convert.__main__ import main as convert_main
from gjob_pipeline.stages.example import Example
from gjob_pipeline.stages.example.__main__ import main as example_main


def test_import():
    """Trivial test that the package is importable."""
    import gjob  # noqa: F401, PLC0415


@pytest.mark.skipif(bool(environ.get("CI")), reason="No example test data yet.")
@pytest.mark.slow
def test_example():
    example_main(Example())


@pytest.mark.skipif(bool(environ.get("CI")), reason="No example test data yet.")
@pytest.mark.slow
def test_convert():
    convert_main(Convert())
