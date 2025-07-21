"""Notebook operations."""

from collections.abc import Callable, Iterable
from concurrent.futures import Future, ProcessPoolExecutor
from typing import Any

from pipeline_helper.models.params import Params
from pipeline_helper.models.stage import Deps, Outs
from pipeline_helper.notebook_namespaces import get_nb_ns


def apply_to_nb(nb: str, params: Params[Deps, Outs], **kwds: Any):
    """Apply a process to a notebook."""
    return get_nb_ns(
        nb=nb, params={"PARAMS": params.model_dump_json(), **kwds}
    ).params.data


def submit_nb_process(
    executor: ProcessPoolExecutor, nb: str, params: Params[Deps, Outs], **kwds: Any
) -> Future[None]:
    """Submit a notebook process to an executor."""
    return executor.submit(apply_to_nb, nb=nb, params=params, **kwds)


def callbacks(
    future: Future[None], /, callbacks: Iterable[Callable[[Future[None]], None]]
):
    """Apply a series of done callbacks to the future."""
    for callback in callbacks:
        callback(future)
