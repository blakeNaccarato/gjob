from itertools import chain
from json import dumps, loads
from shlex import quote, split

from structlog import get_logger

from gjob_pipeline import just, prettify, temporary_path
from gjob_pipeline.models import RawMessage
from gjob_pipeline.parser import invoke
from gjob_pipeline.stages.get_mail import GetMail as Params

log = get_logger()


def main(params: Params):
    mail = set(
        chain.from_iterable(
            get_messages(mbox.read_text(encoding="utf-8"))
            for mbox in params.deps.mboxes.iterdir()
        )
    )
    params.outs.mail.write_text(
        encoding="utf-8",
        data=prettify(
            dumps([
                message.model_dump(mode="json")
                for message in mail
                if message.sender
                == "Job Alerts from Google <notify-noreply@google.com>"
            ])
        ),
    )


def get_messages(mbox: str) -> list[RawMessage]:
    with temporary_path() as dep, temporary_path() as out:
        dep.write_text(encoding="utf-8", data=mbox)
        cmd = f"proj::convert-mbox-to-json {quote(dep.as_posix())} {quote(out.as_posix())}"
        log(just(*split(cmd)).stdout.strip())
        return [RawMessage(**msg) for msg in loads(out.read_text(encoding="utf-8"))]


if __name__ == "__main__":
    invoke(Params)
