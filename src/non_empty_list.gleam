import gleam/dict.{type Dict}
import gleam/list
import gleam/order.{type Order}
import gleam/pair
import gleam/result

/// A list that is guaranteed to contain at least one item.
///
pub type NonEmptyList(a) {
  NonEmptyList(first: a, rest: List(a))
}

/// Joins a non-empty list onto the end of a non-empty list.
///
/// This function runs in linear time, and it traverses and copies the first non-empty list.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > |> append(new(5, [6, 7]))
/// NonEmptyList(1, [2, 3, 4, 5, 6, 7])
/// ```
///
/// ```gleam
/// > single("a")
/// > |> append(new("b", ["c"])
/// NonEmptyList("a", ["b", "c"])
/// ````
///
pub fn append(
  first: NonEmptyList(a),
  second: NonEmptyList(a),
) -> NonEmptyList(a) {
  new(first.first, list.append(first.rest, to_list(second)))
}

/// Joins a list onto the end of a non-empty list.
///
/// This function runs in linear time, and it traverses and copies the first non-empty list.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > |> append_list([5, 6, 7])
/// NonEmptyList(1, [2, 3, 4, 5, 6, 7])
/// ```
///
/// ```gleam
/// > new("a", ["b", "c"])
/// > |> append_list([])
/// NonEmptyList("a", ["b", "c"])
/// ```
///
pub fn append_list(first: NonEmptyList(a), second: List(a)) -> NonEmptyList(a) {
  new(first.first, list.append(first.rest, second))
}

/// Returns a list that is the given non-empty list with up to the given
/// number of elements removed from the front of the list.
///
/// ## Examples
///
/// ```gleam
/// > new("a", ["b", "c"])
/// > |> drop(up_to: 2)
/// ["c"]
/// ```
///
/// ```gleam
/// > new("a", ["b", "c"])
/// > |> drop(up_to: 3)
/// []
/// ```
///
pub fn drop(from list: NonEmptyList(a), up_to n: Int) -> List(a) {
  list
  |> to_list
  |> list.drop(up_to: n)
}

/// Gets the first element from the start of the non-empty list.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > |> first
/// 1
/// ```
///
pub fn first(list: NonEmptyList(a)) -> a {
  list.first
}

/// Maps the non-empty list with the given function and then flattens it.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [3, 5])
/// > |> flat_map(fn(x) { new(x, [x + 1]) })
/// NonEmptyList(1, [2, 3, 4, 5, 6])
/// ```
///
pub fn flat_map(
  over list: NonEmptyList(a),
  with fun: fn(a) -> NonEmptyList(b),
) -> NonEmptyList(b) {
  list
  |> map(fun)
  |> flatten
}

/// Flattens a non-empty list of non-empty lists into a single non-empty list.
///
/// This function traverses all elements twice.
///
/// ### Examples
///
/// ```gleam
/// > new(new(1, [2, 3]), [new(3, [4, 5])])
/// > |> flatten
/// NonEmptyList(1, [2, 3, 4, 5])
/// ```
///
pub fn flatten(lists: NonEmptyList(NonEmptyList(a))) -> NonEmptyList(a) {
  do_flatten(lists.rest, reverse(lists.first))
}

fn do_flatten(
  lists: List(NonEmptyList(a)),
  accumulator: NonEmptyList(a),
) -> NonEmptyList(a) {
  case lists {
    [] -> reverse(accumulator)
    [list, ..further_lists] ->
      do_flatten(further_lists, reverse_and_prepend(list, accumulator))
  }
}

fn reverse_and_prepend(
  list prefix: NonEmptyList(a),
  to suffix: NonEmptyList(a),
) -> NonEmptyList(a) {
  case prefix.rest {
    [] -> new(prefix.first, to_list(suffix))
    [first, ..rest] ->
      reverse_and_prepend(new(first, rest), new(prefix.first, to_list(suffix)))
  }
}

/// Attempts to turn a list into a non-empty list, fails if the starting
/// list is empty.
///
/// ## Examples
///
/// ```gleam
/// > from_list([1, 2, 3, 4])
/// Ok(NonEmptyList(1, [2, 3, 4]))
/// ```
///
/// ```gleam
/// > from_list(["a"])
/// Ok(NonEmptyList("a", []))
/// ```
///
/// ```gleam
/// > from_list([])
/// Error(Nil)
/// ```
///
pub fn from_list(list: List(a)) -> Result(NonEmptyList(a), Nil) {
  case list {
    [] -> Error(Nil)
    [first, ..rest] -> Ok(new(first, rest))
  }
}

/// Takes a list and groups the values by a key
/// which is built from a key function.
///
/// Does not preserve the initial value order.
///
/// ## Examples
///
/// ```gleam
/// import gleam/dict
///
/// new(Ok(3), [Error("Wrong"), Ok(200), Ok(73)])
/// |> group(by: fn(i) {
///   case i {
///     Ok(_) -> "Successful"
///     Error(_) -> "Failed"
///   }
/// })
/// |> dict.to_list
/// // -> [
/// //   #("Failed", NonEmptyList(Error("Wrong"), [])),
/// //   #("Successful", NonEmptyList(Ok(73), [Ok(200), Ok(3)])),
/// // ]
/// ```
///
/// ```gleam
/// import gleam/dict
/// 
/// new(1, [2,3,4,5])
/// |> group(by: fn(i) { i - i / 3 * 3 })
/// |> dict.to_list
/// // -> [#(0, NonEmptyList(3, [])), #(1, NonEmptyList(4, [1])), #(2, NonEmptyList(5, [2]))]
/// ```
///
pub fn group(
  list: NonEmptyList(v),
  by key: fn(v) -> k,
) -> Dict(k, NonEmptyList(v)) {
  list
  |> to_list
  |> list.group(by: key)
  |> dict.map_values(fn(_, group) {
    let assert Ok(group) = from_list(group)
    group
  })
}

/// Returns a new list containing only the elements of the first list after the
/// function has been applied to each one and their index.
///
/// The index starts at 0, so the first element is 0, the second is 1, and so on.
///
/// ## Examples
///
/// ```gleam
/// > new("a", ["b", "c"])
/// > |> index_map(fn(index, letter) { #(index, letter) })
/// NonEmptyList(#(0, "a"), [#(1, "b"), #(2, "c")])
/// ```
///
pub fn index_map(
  list: NonEmptyList(a),
  with fun: fn(Int, a) -> b,
) -> NonEmptyList(b) {
  new(fun(0, list.first), do_index_map(list.rest, [], 1, fun))
}

fn do_index_map(
  list: List(a),
  accumulator: List(b),
  index: Int,
  fun: fn(Int, a) -> b,
) -> List(b) {
  case list {
    [] -> list.reverse(accumulator)
    [first, ..rest] ->
      do_index_map(rest, [fun(index, first), ..accumulator], index + 1, fun)
  }
}

/// Inserts a given value between each existing element in a given list.
///
/// This function runs in linear time and copies the list.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > |> intersperse(with: 0)
/// NonEmptyList(1, [0, 2, 0, 3, 0, 4])
/// ```
///
/// ```gleam
/// > single("a")
/// > |> intersperse(with: "z")
/// NonEmptyList("a", ["z"])
/// ```
///
pub fn intersperse(list: NonEmptyList(a), with elem: a) -> NonEmptyList(a) {
  new(list.first, [elem, ..list.intersperse(list.rest, with: elem)])
}

/// Returns the last element in the given list.
///
/// This function runs in linear time.
/// For a collection oriented around performant access at either end,
/// see `gleam/queue.Queue`.
///
/// ## Examples
///
/// ```gleam
/// > single(1)
/// > |> last
/// 1
/// ```
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > |> last
/// 4
/// ```
///
pub fn last(list: NonEmptyList(a)) -> a {
  list.last(list.rest)
  |> result.unwrap(list.first)
}

/// Returns a new non-empty list containing only the elements of the first
/// non-empty list after the function has been applied to each one.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3])
/// > |> map(fn(x) { x + 1 })
/// NonEmptyList(2, [3, 4])
/// ```
///
pub fn map(over list: NonEmptyList(a), with fun: fn(a) -> b) -> NonEmptyList(b) {
  new(fun(list.first), list.map(list.rest, with: fun))
}

/// Combines two non-empty lists into a single non-empty list using the given
/// function.
///
/// If a list is longer than the other the extra elements are dropped.
///
/// ## Examples
///
/// ```gleam
/// > map2(new(1, [2, 3]), new(4, [5, 6]), fn(x, y) { x + y }) |> to_list
/// [5, 7, 9]
/// ```
///
/// ```gleam
/// > map2(new(1, [2]), new("a", ["b", "c"]), fn(i, x) { #(i, x) }) |> to_list
/// [#(1, "a"), #(2, "b")]
/// ```
///
pub fn map2(
  list1: NonEmptyList(a),
  list2: NonEmptyList(b),
  with fun: fn(a, b) -> c,
) -> NonEmptyList(c) {
  do_map2(single(fun(list1.first, list2.first)), list1.rest, list2.rest, fun)
}

fn do_map2(
  acc: NonEmptyList(c),
  list1: List(a),
  list2: List(b),
  with fun: fn(a, b) -> c,
) -> NonEmptyList(c) {
  case list1, list2 {
    [], _ | _, [] -> reverse(acc)
    [first_a, ..rest_as], [first_b, ..rest_bs] ->
      prepend(acc, fun(first_a, first_b))
      |> do_map2(rest_as, rest_bs, fun)
  }
}

/// Similar to `map` but also lets you pass around an accumulated value.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3])
/// > |> map_fold(from: 100, with: fn(memo, n) { #(memo + i, i * 2) })
/// #(106, NonEmptyList(2, [4, 6]))
/// ```
///
pub fn map_fold(
  over list: NonEmptyList(a),
  from acc: b,
  with fun: fn(b, a) -> #(b, c),
) -> #(b, NonEmptyList(c)) {
  let #(acc, first_elem) = fun(acc, list.first)
  list.fold(
    over: list.rest,
    from: #(acc, single(first_elem)),
    with: fn(acc_non_empty, item) {
      let #(acc, non_empty) = acc_non_empty
      let #(acc, new_item) = fun(acc, item)
      #(acc, prepend(to: non_empty, this: new_item))
    },
  )
  |> pair.map_second(reverse)
}

/// Creates a new non-empty list given its first element and a list
/// for the rest of the elements.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// NonEmptyList(1, [2, 3, 4])
/// ```
/// ```gleam
/// > new("a", [])
/// NonEmptyList("a", [])
/// ```
///
pub fn new(first: a, rest: List(a)) -> NonEmptyList(a) {
  NonEmptyList(first, rest)
}

/// Prefixes an item to a non-empty list.
///
/// ## Examples
///
/// ```gleam
/// > new(2, [3, 4])
/// > |> prepend(1)
/// NonEmptyList(1, [2, 3, 4])
/// ```
///
pub fn prepend(to list: NonEmptyList(a), this item: a) -> NonEmptyList(a) {
  new(item, [list.first, ..list.rest])
}

/// This function acts similar to fold, but does not take an initial state.
/// Instead, it starts from the first element in the non-empty list and combines it with each
/// subsequent element in turn using the given function.
/// The function is called as `fun(accumulator, current_element)`.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > |> reduce(fn(acc, x) { acc + x })
/// 10
/// ```
///
pub fn reduce(over list: NonEmptyList(a), with fun: fn(a, a) -> a) -> a {
  list.fold(over: list.rest, from: list.first, with: fun)
}

/// Returns the list minus the first element. Since the remaining list could
/// be empty this functions returns a normal list.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > |> rest
/// [2, 3, 4]
/// ```
///
/// ```gleam
/// > single(1)
/// > |> rest
/// []
/// ```
///
pub fn rest(list: NonEmptyList(a)) -> List(a) {
  list.rest
}

/// Creates a new non-empty list from a given non-empty list containing the same elements
/// but in the opposite order.
///
/// This function has to traverse the non-empty list to create the new reversed
/// non-empty list, so it runs in linear time.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > |> reverse
/// NonEmptyList(4, [3, 2, 1])
/// ```
///
pub fn reverse(list: NonEmptyList(a)) -> NonEmptyList(a) {
  let assert Ok(reversed) =
    list
    |> to_list
    |> list.reverse
    |> from_list
  reversed
}

/// Similar to fold, but yields the state of the accumulator at each stage.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > |> scan(from: 100, with: fn(acc, i) { acc + i })
/// NonEmptyList(101 [103, 106, 110])
/// ```
///
pub fn scan(
  over list: NonEmptyList(a),
  from initial: b,
  with fun: fn(b, a) -> b,
) -> NonEmptyList(b) {
  let assert Ok(scanned) =
    list
    |> to_list
    |> list.scan(from: initial, with: fun)
    |> from_list
  scanned
}

/// Takes a non-empty list, randomly sorts all items and returns the shuffled
/// non-empty list.
///
/// This function uses Erlang's `:rand` module or Javascript's
/// `Math.random()` to calcuate the index shuffling.
///
/// ## Examples
///
/// ```gleam
/// > new("a", ["b", "c", "d"])
/// > |> shuffle
/// NonEmptyList("c", ["a", "d", "b"])
/// ```
///
pub fn shuffle(list: NonEmptyList(a)) -> NonEmptyList(a) {
  let assert Ok(shuffled) =
    list
    |> to_list
    |> list.shuffle
    |> from_list
  shuffled
}

/// Creates a non-empty list with a single element.
///
/// ## Examples
///
/// ```gleam
/// > single(1)
/// NonEmptyList(1, [])
/// ```
///
pub fn single(first: a) -> NonEmptyList(a) {
  new(first, [])
}

/// Sorts a given non-empty list from smallest to largest based upon the
/// ordering specified by a given function.
///
/// ## Examples
///
/// ```gleam
/// > import gleam/int
/// > new(4, [1, 3, 4, 2, 6, 5])
/// > sort(by: int.compare)
/// NonEmptyList(1, [2, 3, 4, 4, 5, 6])
/// ```
///
pub fn sort(
  list: NonEmptyList(a),
  by compare: fn(a, a) -> Order,
) -> NonEmptyList(a) {
  let assert Ok(sorted) =
    list
    |> to_list
    |> list.sort(by: compare)
    |> from_list
  sorted
}

/// Takes two non-empty lists and returns a single non-empty list of 2-element tuples.
///
/// If one of the non-empty lists is longer than the other, an `Error` is returned.
///
/// ## Examples
///
/// ```gleam
/// > strict_zip(single(1), new("a", ["b", "c"]))
/// Error(Nil)
/// ```
///
/// ```gleam
/// > strict_zip(new(1, [2, 3]), single("a"))
/// Error(Nil)
/// ```
///
/// ```gleam
/// > strict_zip(new(1, [2, 3]), new("a", ["b", "c"]))
/// Ok(NonEmptyList(#(1, "a"), [#(2, "b"), #(3, "c")]))
/// ```
///
pub fn strict_zip(
  list: NonEmptyList(a),
  with other: NonEmptyList(b),
) -> Result(NonEmptyList(#(a, b)), Nil) {
  case list.length(to_list(list)) == list.length(to_list(other)) {
    True -> Ok(zip(list, with: other))
    False -> Error(Nil)
  }
}

/// Returns a list containing the first given number of elements from the given
/// non-empty list.
///
/// If the element has less than the number of elements then the full list is
/// returned.
///
/// This function runs in linear time but does not copy the list.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > take(2)
/// [1, 2]
/// ```
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > take(9)
/// [1, 2, 3, 4]
/// ```
///
pub fn take(from list: NonEmptyList(a), up_to n: Int) -> List(a) {
  list
  |> to_list
  |> list.take(n)
}

/// Turns a non-empty list back into a normal list with the same
/// elements.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [2, 3, 4])
/// > |> to_list
/// [1, 2, 3, 4]
/// ```
///
/// ```gleam
/// > single("a")
/// > |> to_list
/// ["a"]
/// ```
///
pub fn to_list(non_empty: NonEmptyList(a)) -> List(a) {
  [non_empty.first, ..non_empty.rest]
}

/// Removes any duplicate elements from a given list.
///
/// This function returns in loglinear time.
///
/// ## Examples
///
/// ```gleam
/// > new(1, [1, 2, 3, 1, 4, 4, 3])
/// > |> unique
/// NonEmptyList(1, [2, 3, 4])
/// ```
///
pub fn unique(list: NonEmptyList(a)) -> NonEmptyList(a) {
  let assert Ok(unique) =
    list
    |> to_list
    |> list.unique
    |> from_list
  unique
}

/// Takes a single non-empty list of 2-element tuples and returns two
/// non-empty lists.
///
/// ## Examples
///
/// ```gleam
/// > new(#(1, "a"), [#(2, "b"), #(3, "c")])
/// > |> unzip
/// #(NonEmptyList(1, [2, 3]), NonEmptyList("a", ["b", "c"]))
/// ```
///
pub fn unzip(list: NonEmptyList(#(a, b))) -> #(NonEmptyList(a), NonEmptyList(b)) {
  list.unzip(list.rest)
  |> pair.map_first(new(list.first.0, _))
  |> pair.map_second(new(list.first.1, _))
}

/// Takes two non-empty lists and returns a single non-empty list of 2-element tuples.
///
/// If one of the non-empty lists is longer than the other, the remaining elements from
/// the longer non-empty list are not used.
///
/// ## Examples
///
/// ```gleam
/// > zip(new(1, [2, 3]), single("a"))
/// NonEmptyList(#(1, "a"), [])
/// ```
///
/// ```gleam
/// > zip(single(1), new("a", ["b", "c"]))
/// NonEmptyList(#(1, "a"), [])
/// ```
///
/// ```gleam
/// > zip(new(1, [2, 3]), new("a", ["b", "c"]))
/// NonEmptyList(#(1, "a"), [#(2, "b"), #(3, "c")])
/// ```
///
pub fn zip(
  list: NonEmptyList(a),
  with other: NonEmptyList(b),
) -> NonEmptyList(#(a, b)) {
  new(#(list.first, other.first), list.zip(list.rest, other.rest))
}
