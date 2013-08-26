#! /bin/sh

env ERL_LIBS=. erl -sname endi -config etc/app.config -s endi_app
