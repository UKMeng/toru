FROM python:3.12 as requirements_stage

WORKDIR /wheel

RUN python -m pip install --user pipx

RUN apt-get update && apt-get install -y build-essential unzip wget git nano

COPY ./pyproject.toml \
  ./poetry.lock \
  /wheel/

RUN python -m pipx run --no-cache poetry export -f requirements.txt --output requirements.txt --without-hashes

RUN python -m pip wheel --wheel-dir=/wheel --no-cache-dir --requirement ./requirements.txt

RUN python -m pipx run --no-cache nb-cli generate -f /tmp/bot.py


FROM python:3.12-slim

WORKDIR /app

ENV TZ Asia/Shanghai
ENV PYTHONPATH=/app

COPY ./docker/gunicorn_conf.py ./docker/start.sh /
RUN chmod +x /start.sh

ENV APP_MODULE _main:app
ENV MAX_WORKERS 1

COPY --from=requirements_stage /tmp/bot.py /app
COPY ./docker/_main.py /app
COPY --from=requirements_stage /wheel /wheel

RUN python -m pip install --user pipx
RUN python -m pipv ensurepath
RUN pipx install nb-cli

RUN pip install --no-cache-dir gunicorn uvicorn[standard] nonebot2 \
  && pip install --no-cache-dir --no-index --force-reinstall --find-links=/wheel -r /wheel/requirements.txt && rm -rf /wheel

RUN playwright install-deps
RUN playwright install chromium
RUN apt-get update \
  && apt-get install -y --no-install-recommends locales fontconfig fonts-noto-color-emoji gettext \
  && localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8 \
  && fc-cache -fv \
  && apt-get purge -y --auto-remove \
  && rm -rf /var/lib/apt/lists/*

COPY . /app/

CMD ["/start.sh"]