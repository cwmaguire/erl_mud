%% Copyright (c) 2017, Chris Maguire <cwmaguire@gmail.com>
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
-module(gerlshmud_handler_resource_tick).
-behaviour(gerlshmud_handler).

%% This is a tick handler for a resource process. Resource processes manage
%% how often other processes can perform actions such as attacks. Resource
%% processes gain more resources to allocate with each tick. When a tick
%% event occurs the resource will allocate that resource to the next
%% process or processes in line depending on how much each next successive
%% process needs.

-include("include/gerlshmud.hrl").

-export([attempt/1]).
-export([succeed/1]).
-export([fail/1]).

attempt({#parents{}, Props, {Self, tick, Ref, with, Count}})
  when Self == self() ->
    Log = [{?SOURCE, Self},
           {?EVENT, tick},
           {ref, Ref},
           {count, Count}],
    case proplists:get_value(tick, Props, undefined) of
        Ref ->
            {succeed, true, Props, Log};
        _ ->
            {{fail, <<"unmatched (stale?) resource tick">>}, false, Props, Log}
    end;

attempt(_) ->
    undefined.

succeed({Props, {Self, tick, Ref, with, Count}})
  when Self == self() ->
    Log = [{?SOURCE, Self},
           {?EVENT, tick},
           {handler, ?MODULE},
           {ref, Ref},
           {count, Count}],
    Current = proplists:get_value(current, Props, 0),
    Max = proplists:get_value(max, Props, 0),
    New = min(Count + Current, Max),
    PerTick = proplists:get_value(per_tick, Props, 1),
    TickTime = proplists:get_value(tick_time, Props, _OneSecond = 1000),
    Reservations = proplists:get_value(reservations, Props, []),
    {RotatedReservations, Remaining} =
        case {Reservations, New} of
            {[], Max} ->
                {[], Max};
            _ ->
                %% For now just make each tick take at _least_ PerTick
                %% millis instead of trying to wait close to a PerTick,
                %% or trying to correct for a long previous tick.
                gerlshmud_object:attempt_after(TickTime, Self, {Self, tick, Ref, with, PerTick}),
                Type = proplists:get_value(type, Props),
                allocate(Type, Reservations, New)
        end,
    OtherProps = lists:keydelete(reservations, 1, lists:keydelete(current, 1, Props)),
    Props2 = [{current, Remaining}, {reservations, RotatedReservations} | OtherProps],
    {Props2, Log};

succeed({Props, _}) ->
    Props.

fail({Props, _, _}) ->
    Props.

allocate(Type, [{Proc, Required} | Reservations], Available)
  when Available >= Required ->
    gerlshmud_object:attempt(Proc, {self(), allocate, Required, 'of', Type, to, Proc}),
    RotatedReservations = Reservations ++ [{Proc, Required}],
    allocate(Type, RotatedReservations, Available - Required);
allocate(_, Reservations, Available) ->
    {Reservations, Available}.


