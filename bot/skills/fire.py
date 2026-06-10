import logging

from telegram import Update, User
from telegram.ext import ContextTypes
from typing_utils import App, get_job_queue

from mode import cleanup_queue_update
from handlers import ChatCommandHandler

logger = logging.getLogger(__name__)


def add_fire(app: App, handlers_group: int):
    logger.info("registering fire handlers")
    app.add_handler(ChatCommandHandler("fire", fire), group=handlers_group)


async def fire(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message is None or update.message.reply_to_message is None:
        return
    if update.effective_chat is None:
        return
    user: User | None = update.message.reply_to_message.from_user
    chat_id = update.effective_chat.id

    if user and chat_id:
        reason = " ".join(context.args or []).strip()
        text = f"Пользователь {user.name} уволен"
        if reason:
            text = f"{text} {reason}"
        result = await context.bot.send_message(chat_id, text)
        cleanup_queue_update(
            get_job_queue(context),
            update.message,
            result,
            600,
            remove_cmd=True,
            remove_reply=False,
        )
