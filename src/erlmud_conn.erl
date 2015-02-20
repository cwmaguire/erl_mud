%% Copyright (c) 2015, Chris Maguire <cwmaguire@gmail.com>
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
%% ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
%% OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
-module(erlmud_conn).
-behaviour(gen_fsm).

-export([start_link/1]).
-export([handle/2]).

-export([login/2]).
-export([password/2]).
-export([live/2]).

-export([init/1]).
-export([handle_event/3]).
-export([handle_sync_event/4]).
-export([handle_info/3]).
-export([terminate/3]).
-export([code_change/4]).

-record(state, {socket :: pid(),
                login :: string(),
                room :: pid(),
                attempts = 0 :: integer()}).

%% api

start_link(Socket) ->
    gen_fsm:start_link(?MODULE, Socket, []).

handle(Pid, Msg) ->
    gen_fsm:send_event(Pid, Msg).

%% states

login(Event, StateData) ->
    {next_state, password, StateData#state{login = Event}}.

password(Event, StateData = #state{login = Login,
                                   attempts = Attempts,
                                   socket = Socket}) ->
    case is_valid_creds(Login, Event) of
        true ->
            Socket ! {send, "login succeeded"},
            {next_state, live, StateData#state{login = undefined}};
        false ->
            {next_state, login, StateData#state{login = undefined,
                                                attempts = Attempts + 1}}
    end.

live(Event, StateData) ->
    io:format("erlmud_conn got event ~p in state 'live' with state data ~p~n", [Event, StateData]),
    {next_state, live, StateData}.

%% gen_fsm

init(Socket) ->
    {ok, login, #state{socket = Socket}}.

handle_sync_event(_Event, _From, StateName, StateData) ->
    {reply, ok, StateName, StateData}.

handle_event(_Info, StateName, StateData) ->
    {next_state, StateName, StateData}.

handle_info(_Info, StateName, StateData) ->
    {next_state, StateName, StateData}.

terminate(_Reason, _StateName, _StateData) -> ok.
code_change(_OldVsn, StateName, StateData, _Extra) ->
    {ok, StateName, StateData}.

%% private

is_valid_creds(_Login, _Password) ->
    true.
