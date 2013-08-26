REBAR=env ERL_LIBS=.. ./rebar

all: deps compile

deps:
	@$(REBAR) get-deps

compile: deps
	@$(REBAR) compile

test:
	@$(REBAR) eunit

ct: compile
	@$(REBAR) ct skip_deps=true

clean:
	@$(REBAR) clean

clean_logs:
	rm -rf log/

run: compile clean_logs
	./start.sh

