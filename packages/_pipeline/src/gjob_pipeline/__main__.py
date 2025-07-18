"""Command-line interface."""

from gjob_pipeline.cli import Pipeline
from gjob_pipeline.parser import invoke


def main():
    """CLI entry-point."""
    invoke(Pipeline)


if __name__ == "__main__":
    main()
