from gjob_pipeline.notebook_namespaces import get_nb_ns
from gjob_pipeline.stages.convert import Convert as Params


def main(params: Params):
    nb = params.deps.nb.read_text(encoding="utf-8")
    get_nb_ns(nb=nb, params={"PARAMS": params.model_dump_json()})


if __name__ == "__main__":
    main(Params())
