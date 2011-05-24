%%
%% @doc This module implements a hash ring.
%% Items are hashed into the ring NumReplicas times.
%%
%% An item is hashed using the following:
%%
%% sha1(Item + string(N)) where N is (1..NumReplicas)
%%
%% Note: When N is converted to a string it is not zero padded.
%%
-module(hash_ring).

-export([
  create_ring/2,
  get_item/2,
  add_item/2,
  remove_item/2
]).

%%
%% @doc Finds the item that contains the Key on the Ring
%%
get_item(Key, {_NumReplicas, Circle}) ->
  Point = hash_key(Key),
  {Item, _Replica} = case lists:dropwhile(fun({_Item, Replica}) ->
    Replica =< Point
  end, Circle) of
    [] ->
      hd(Circle);
    [H|_T] ->
      H
  end,
  Item.

%%
%% @doc Creates a hash ring that places Items in the ring NumReplicas times
%%
%% A "replica" just means that the Item is placed on the ring in multiple places to 
%% make the distribution more even.
%%
create_ring(Items, NumReplicas) ->
    lists:foldl(fun(Item, Ring) ->
        add_item(Item, Ring)
    end, {NumReplicas, []}, Items).

%%
%% @doc Adds an item into the ring.
%% Returns the ring with item added in.
%% 
add_item(Item, {NumReplicas, Circle}) ->
    sort_ring({NumReplicas, lists:flatten(lists:append(Circle, get_item_points(Item, NumReplicas)))}).

%%
%% @doc Removes an item and its replicas from the ring.
%% Returns the ring without the item.
%%    
remove_item(Item, {NumReplicas, Circle}) ->
    Points = get_item_points(Item, NumReplicas),
    sort_ring({NumReplicas, lists:filter(fun(Point) -> 
        not lists:member(Point, Points)
    end, Circle)}).

%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Internal functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%

sort_ring({NumReplicas, Circle}) ->
    {NumReplicas, lists:usort(fun({_ItemA, PartitionA}, {_ItemB, PartitionB}) ->
        PartitionA =< PartitionB
    end, Circle)}.

%%
%% @doc This function returns a list of N {Item, Point} tuples
%% 
%% Each point is generated by hashing (item + 1) to (item + n) to evenly distribute the points
%%
get_item_points(Item, N) ->
  lists:map(fun(Partition) ->
    {Item, Partition}
  end,
  lists:usort(lists:map(fun(X) ->
    hash_key(Item ++ integer_to_list(X))
  end, lists:seq(1, N)))).

%%
%% Hashes the given Key with SHA1 and converts it to a big integer
%%
hash_key(Key) when is_binary(Key) ->
    hash_key(binary_to_list(Key));
hash_key(Key) ->
  <<Int:160/unsigned-integer>> = crypto:sha(Key),
  Int.
  

%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Tests
%%%%%%%%%%%%%%%%%%%%%%%%%%%
-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

hash_key_known_test() ->
  lists:foreach(fun(_) ->
    ?assertEqual(653878565946713713149629104275478104571867727804, hash_key("test123"))
  end, lists:seq(1, 1000)).

add_remove_item_test() ->
    Ring = create_ring([], 2),
    
    PointA1 = hash_key("A1"),
    PointA2 = hash_key("A2"),
    PointB1 = hash_key("B1"),
    PointB2 = hash_key("B2"),
    
    AddedRing = add_item("B", add_item("A", Ring)),
    ?assertEqual({2, [
        {"A", PointA1},
        {"A", PointA2},
        {"B", PointB2},
        {"B", PointB1}
    ]}, AddedRing),
    
    RemovedRing = remove_item("A", AddedRing),
    ?assertEqual({2, [
        {"B", PointB2},
        {"B", PointB1}
    ]}, RemovedRing).

-endif.
