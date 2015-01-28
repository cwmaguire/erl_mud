-module(erlmud_player).

-export([procs/1]).
-export([create/1]).
-export([handle/2]).

-define(FIELDS, [{room, undefined}, {items, []}, {messages, []}]).
-define(PV(K, PL, Dflt), proplists:get_value(K, PL, Dflt)).
-define(PV(K, PL), ?PV(K, PL, undefined)).

procs(Props) ->
    Fields = [room, items],
    lists:flatten([?PV(Field, Props, Dflt) || {Field, Dflt} <- Fields]).

create(Props) ->
    [{Field, ?PV(Field, Props, [])} || Field <- ?FIELDS].

handle(Msg = {attempt, _}, State) ->
    log(Msg, State),
    {true, true, State};
handle(Msg, State) ->
    log(Msg, State),
    State.

log(Msg, State) ->
    io:format("Player received: ~p~n"
              "with state: ~p~n",
              [Msg, State]).
