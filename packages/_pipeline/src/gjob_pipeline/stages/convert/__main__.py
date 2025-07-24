from pipeline_helper.notebook_namespaces import get_nb_ns

from gjob_pipeline.parser import invoke
from gjob_pipeline.stages.convert import Convert as Params


def main(params: Params):
    get_nb_ns(nb=params.deps.nb.read_text(encoding="utf-8"), display_stdout=True)


if __name__ == "__main__":
    invoke(Params)
