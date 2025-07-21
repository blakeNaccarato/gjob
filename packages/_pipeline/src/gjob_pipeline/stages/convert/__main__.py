from concurrent.futures import ProcessPoolExecutor

from pipeline_helper.nbs import submit_nb_process

from gjob_pipeline.parser import invoke
from gjob_pipeline.stages.convert import Convert as Params


def main(params: Params):
    nb = params.deps.nb.read_text(encoding="utf-8")
    with ProcessPoolExecutor(max_workers=4) as executor:
        for mbox in sorted(params.deps.mboxes.iterdir()):
            params_ = params.model_copy(deep=True)
            params_.mbox_name = mbox.name
            submit_nb_process(executor=executor, nb=nb, params=params_)


if __name__ == "__main__":
    invoke(Params)
