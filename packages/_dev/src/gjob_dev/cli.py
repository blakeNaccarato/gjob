from pathlib import Path

from cappa.base import command


@command(invoke="gjob_dev.tools.elevate_pyright_warnings")
class ElevatePyrightWarnings:
    """Elevate Pyright warnings to errors."""

    path: Path | None = Path("pyrightconfig.json")
