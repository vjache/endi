%%%-------------------------------------------------------------------
%%% @author Vorobyov Vyacheslav <vjache@gmail.com>
%%% @copyright (C) 2013, Vorobyov Vyacheslav
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(endi_srv).

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

-record(state, { nodes_to_discover = [], nodes_discovered = []}).

-define(LOG_INFO(Rep), error_logger:info_report(Rep) ).

%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    NodesSpecs = application:get_env(endi, nodes, []),
    Nodes = [node_spec_to_node(NodeSpec) || NodeSpec <- NodesSpecs ],
    net_kernel:monitor_nodes(true),
    {ok, _} = timer:send_interval(1000,  do_ping),
    ?LOG_INFO([start_node_discoverer, {nodes_to_discover, Nodes}]),
    {ok, #state{ nodes_to_discover = Nodes}}.

node_spec_to_node(NodeSpec) ->
    case NodeSpec of
	_ when is_atom(NodeSpec) ->
	    case lists:member('@',atom_to_list(NodeSpec)) of
		true  -> NodeSpec;
		false -> node_spec_to_node({NodeSpec, localhost})
	    end;
	{NodeShortName, localhost} ->
	    [_, Host] = string:tokens(atom_to_list(node()), "@"),
	    list_to_atom( atom_to_list(NodeShortName) ++ "@" ++ Host ) 
    end.

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(do_ping, #state{nodes_to_discover = Nodes} = State) ->
    [ net_adm:ping(N) || N <- Nodes ],
    {noreply, State};
%{nodeup, Node, InfoList} | {nodedown, Node, InfoList}
handle_info({nodeup, Node}, #state{nodes_to_discover = NNodes, 
				   nodes_discovered = DNodes} = State) ->
    case lists:member(Node, NNodes) of
	true ->
	    NNodes1 = lists:delete(Node, NNodes),
	    DNodes1 = [ Node | DNodes ],
	    ?LOG_INFO([{node_discovered, Node}]),
	    {noreply, State#state{nodes_to_discover = NNodes1, 
				  nodes_discovered  = DNodes1}};
	false ->
	    {noreply, State}
    end;
handle_info({nodedown, Node}, #state{nodes_to_discover = NNodes, 
				     nodes_discovered  = DNodes} = State) ->
    case lists:member(Node, DNodes) of
	true ->
	    DNodes1 = lists:delete(Node, DNodes),
	    NNodes1 = [ Node | NNodes ],
	    ?LOG_INFO([{node_lost, Node}]),
	    {noreply, State#state{nodes_to_discover = NNodes1, 
				  nodes_discovered  = DNodes1}};
	false ->
	    {noreply, State}
    end.


terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
