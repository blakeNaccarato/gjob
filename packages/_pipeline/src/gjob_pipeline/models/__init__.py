from datetime import datetime
from typing import Annotated as Ann

from pydantic import BaseModel, ConfigDict, Field


class Message(BaseModel):
    model_config = ConfigDict(frozen=True)
    subject: str
    received: datetime
    body: str


class RawMessage(Message):
    sender: Ann[str, Field(validation_alias="from", exclude=True)]
    received: Ann[datetime, Field(validation_alias="date")]
