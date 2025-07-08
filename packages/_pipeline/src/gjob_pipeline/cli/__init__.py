"""Command-line interface."""

from __future__ import annotations

from dataclasses import dataclass

from cappa.subcommand import Subcommands

from gjob_pipeline.cli.experiments import Trackpy
from gjob_pipeline.stages.convert import Convert
from gjob_pipeline.stages.skip_cloud import SkipCloud
from gjob_pipeline.sync_dvc import SyncDvc


@dataclass
class Stage:
    """Run a pipeline stage."""

    commands: Subcommands[SkipCloud | Convert]


@dataclass
class Exp:
    """Run a pipeline experiment."""

    commands: Subcommands[Trackpy]


@dataclass
class GjobPipeline:
    """Run the research data pipeline."""

    commands: Subcommands[SyncDvc | Stage | Exp]
