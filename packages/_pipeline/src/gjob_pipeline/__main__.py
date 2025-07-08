"""Command-line interface."""

from gjob_pipeline.cli import GjobPipeline
from gjob_pipeline.parser import invoke


def main():
    """CLI entry-point."""
    invoke(GjobPipeline)


if __name__ == "__main__":
    main()
