defmodule AVLDict do
  @moduledoc """
  Immutable dictionary implemented as an AVL tree.
  """

  defstruct [:key, :value, :height, :left, :right]

  @type key :: term()
  @type value :: term()
  @type t :: %__MODULE__{} | nil

  @doc "Creates a new empty dictionary."
  @spec new() :: t
  def new, do: nil

  @doc "Alias for `new/0` to satisfy the monoid interface."
  @spec empty() :: t
  def empty, do: new()

  @doc "Builds a dictionary from a list of `{key, value}` pairs."
  @spec from_list([{key, value}]) :: t
  def from_list(list) do
    Enum.reduce(list, new(), fn {k, v}, acc -> put(acc, k, v) end)
  end

  @doc "Converts the dictionary to a list ordered by keys."
  @spec to_list(t) :: [{key, value}]
  def to_list(dict), do: inorder(dict, [])

  @doc "Inserts or replaces a key with the given value."
  @spec put(t, key, value) :: t
  def put(dict, key, value), do: insert(dict, key, value)

  @doc "Deletes the given key if present."
  @spec delete(t, key) :: t
  def delete(dict, key), do: remove(dict, key)

  @doc "Gets the value for the key or returns the default."
  @spec get(t, key, value) :: value
  def get(dict, key, default) do
    case find(dict, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  @doc "Checks if the dictionary contains the key."
  @spec has_key?(t, key) :: boolean()
  def has_key?(dict, key) do
    match?({:ok, _}, find(dict, key))
  end

  @doc """
  Maps each `{key, value}` pair to a new pair, returning a new dictionary.
  Key collisions are resolved by the insertion order of the traversal
  (in-order from smallest to largest).
  """
  @spec map(t, ({key, value} -> {key, value})) :: t
  def map(dict, fun) when is_function(fun, 1) do
    foldl(dict, new(), fn pair, acc ->
      {k, v} = fun.(pair)
      put(acc, k, v)
    end)
  end

  @doc """
  Filters the dictionary, keeping only pairs for which the predicate returns true.
  """
  @spec filter(t, ({key, value} -> boolean())) :: t
  def filter(dict, pred) when is_function(pred, 1) do
    foldl(dict, new(), fn pair = {k, v}, acc ->
      if pred.(pair), do: put(acc, k, v), else: acc
    end)
  end

  @doc """
  Left fold over the dictionary (in-order traversal).
  """
  @spec foldl(t, acc, ({key, value}, acc -> acc)) :: acc when acc: var
  def foldl(dict, acc, fun)

  def foldl(nil, acc, _fun), do: acc

  def foldl(%__MODULE__{left: l, right: r, key: k, value: v}, acc, fun) do
    acc1 = foldl(l, acc, fun)
    acc2 = fun.({k, v}, acc1)
    foldl(r, acc2, fun)
  end

  @doc """
  Right fold over the dictionary (reverse in-order traversal).
  """
  @spec foldr(t, acc, ({key, value}, acc -> acc)) :: acc when acc: var
  def foldr(dict, acc, fun)

  def foldr(nil, acc, _fun), do: acc

  def foldr(%__MODULE__{left: l, right: r, key: k, value: v}, acc, fun) do
    acc1 = foldr(r, acc, fun)
    acc2 = fun.({k, v}, acc1)
    foldr(l, acc2, fun)
  end

  @doc """
  Monoid append operation. Keys from the right dictionary override keys from the left.
  """
  @spec mappend(t, t) :: t
  def mappend(left, right) do
    foldl(right, left || new(), fn {k, v}, acc -> put(acc, k, v) end)
  end

  @doc """
  Compares two dictionaries for equality of keys and values, independent of shape.
  Uses simultaneous in-order traversal without converting to sorted lists.
  """
  @spec equal?(t, t) :: boolean()
  def equal?(a, b) do
    in_order_compare(push_left(a, []), push_left(b, []))
  end

  ## Internal helpers

  defp height(nil), do: 0
  defp height(%__MODULE__{height: h}), do: h

  defp node(key, value, left, right) do
    %__MODULE__{
      key: key,
      value: value,
      left: left,
      right: right,
      height: 1 + max(height(left), height(right))
    }
  end

  defp balance_factor(nil), do: 0
  defp balance_factor(%__MODULE__{left: l, right: r}), do: height(l) - height(r)

  defp rotate_right(%__MODULE__{left: %__MODULE__{} = l} = n) do
    %{key: lk, value: lv, left: ll, right: lr} = l
    node(lk, lv, ll, node(n.key, n.value, lr, n.right))
  end

  defp rotate_left(%__MODULE__{right: %__MODULE__{} = r} = n) do
    %{key: rk, value: rv, left: rl, right: rr} = r
    node(rk, rv, node(n.key, n.value, n.left, rl), rr)
  end

  defp rebalance(%__MODULE__{} = n) do
    bf = balance_factor(n)

    cond do
      bf > 1 and balance_factor(n.left) >= 0 ->
        rotate_right(n)

      bf > 1 ->
        node(n.key, n.value, rotate_left(n.left), n.right) |> rotate_right()

      bf < -1 and balance_factor(n.right) <= 0 ->
        rotate_left(n)

      bf < -1 ->
        node(n.key, n.value, n.left, rotate_right(n.right)) |> rotate_left()

      true ->
        %{n | height: 1 + max(height(n.left), height(n.right))}
    end
  end

  defp insert(nil, key, value), do: node(key, value, nil, nil)

  defp insert(%__MODULE__{key: k} = n, key, value) when key < k do
    node(n.key, n.value, insert(n.left, key, value), n.right) |> rebalance()
  end

  defp insert(%__MODULE__{key: k} = n, key, value) when key > k do
    node(n.key, n.value, n.left, insert(n.right, key, value)) |> rebalance()
  end

  defp insert(%__MODULE__{} = n, _key, value) do
    %{n | value: value}
  end

  defp find(nil, _key), do: :error

  defp find(%__MODULE__{key: k, value: v, left: l, right: r}, key) do
    cond do
      key < k -> find(l, key)
      key > k -> find(r, key)
      true -> {:ok, v}
    end
  end

  defp remove(nil, _key), do: nil

  defp remove(%__MODULE__{key: k, left: l, right: r} = n, key) when key < k do
    node(k, n.value, remove(l, key), r) |> rebalance()
  end

  defp remove(%__MODULE__{key: k, left: l, right: r} = n, key) when key > k do
    node(k, n.value, l, remove(r, key)) |> rebalance()
  end

  defp remove(%__MODULE__{left: nil, right: nil}, _key), do: nil

  defp remove(%__MODULE__{left: nil, right: r}, _key), do: r

  defp remove(%__MODULE__{left: l, right: nil}, _key), do: l

  defp remove(%__MODULE__{right: r} = n, _key) do
    {min_k, min_v, new_right} = extract_min(r)
    node(min_k, min_v, n.left, new_right) |> rebalance()
  end

  defp extract_min(%__MODULE__{left: nil, key: k, value: v, right: r}) do
    {k, v, r}
  end

  defp extract_min(%__MODULE__{left: l} = n) do
    {k, v, new_left} = extract_min(l)
    {k, v, node(n.key, n.value, new_left, n.right) |> rebalance()}
  end

  defp inorder(nil, acc), do: acc

  defp inorder(%__MODULE__{left: l, right: r, key: k, value: v}, acc) do
    acc1 = inorder(r, acc)
    acc2 = [{k, v} | acc1]
    inorder(l, acc2)
  end

  defp push_left(nil, stack), do: stack

  defp push_left(%__MODULE__{} = node, stack) do
    push_left(node.left, [{node, node.right} | stack])
  end

  defp in_order_compare([], []), do: true
  defp in_order_compare([], _), do: false
  defp in_order_compare(_, []), do: false

  defp in_order_compare([{n1, r1} | s1], [{n2, r2} | s2]) do
    if n1.key == n2.key and n1.value == n2.value do
      next1 = push_left(r1, s1)
      next2 = push_left(r2, s2)
      in_order_compare(next1, next2)
    else
      false
    end
  end
end
