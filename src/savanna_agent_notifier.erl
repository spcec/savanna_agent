%%======================================================================
%%
%% LeoProject - Savanna Agent
%%
%% Copyright (c) 2014 Rakuten, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%%======================================================================
-module(savanna_agent_notifier).
-author('Yosuke Hara').

-behaviour(svc_notify_behaviour).

-include("savanna_agent.hrl").
-include_lib("savanna_commons/include/savanna_commons.hrl").
-include_lib("eunit/include/eunit.hrl").

%% callback
-export([notify/1]).


%%--------------------------------------------------------------------
%% Callback
%%--------------------------------------------------------------------
%% @doc
-spec(notify(#sv_result{}) ->
             ok | {error, any()}).
notify(#sv_result{metric_group_name = MetricGroup,
                  adjusted_step = DateTime,
                  col_name = Key,
                  result = Value}) ->
    notify(DateTime, MetricGroup, Key, Value, 1).
%% notify(MetricGroup, DateTime, Key, Value, 1).

%% @private
notify(_DateTime,_MetricGroup,_Key,_Val, ?DEF_MAX_FAIL_COUNT) ->
    %% @TODO enqueue a fail message
    ok;
notify(DateTime, MetricGroup, Key, Val, Times) ->
    %% Retrieve destination node(s)
    case savanna_agent_tbl_members:find_by_state('running') of
        {ok, Members} ->
            %% Notify a message to a destination node
            Len  = length(Members),
            Node = lists:nth(erlang:phash2(
                               leo_date:now(), Len) + 1, Members),
            case notify_1(Node, MetricGroup, DateTime, Key, Val) of
                ok ->
                    ok;
                _ ->
                    notify(DateTime, MetricGroup,
                           Key, Val, Times + 1)
            end;
        _ ->
            notify(DateTime, MetricGroup,
                   Key, Val, ?DEF_MAX_FAIL_COUNT)
    end.


%% @private
notify_1(Node, DateTime, MetricGroup, Key, Val) ->
    case svc_tbl_metric_group:get(MetricGroup) of
        {ok, #sv_metric_group{schema_name = Schema}} ->
            case leo_rpc:call(Node, savannadb_api, notify,
                              [DateTime, Schema,
                               MetricGroup, Key, Val]) of
                ok ->
                    ok;
                _ ->
                    {error, ?ERROR_COULD_NOT_TRANSFER_MSG}
            end;
        _ ->
            {error, ?ERROR_COULD_NOT_GET_SCHEMA}
    end.
