defmodule AVLDictTest do
  use ExUnit.Case
  use ExUnitProperties

  alias AVLDict, as: D

  describe "basic operations" do
    test "new/0 and empty/0 produce empty dict" do
      assert D.new() == nil
      assert D.empty() == D.new()
      assert D.to_list(D.new()) == []
    end

    test "put/3 inserts and overrides values" do
      dict =
        D.new()
        |> D.put(2, :b)
        |> D.put(1, :a)
        |> D.put(2, :c)

      assert D.to_list(dict) == [{1, :a}, {2, :c}]
      assert D.get(dict, 2, :none) == :c
    end

    test "delete/2 removes keys and keeps balance" do
      dict =
        [1, 2, 3, 4, 5]
        |> Enum.reduce(D.new(), fn k, acc -> D.put(acc, k, k) end)
        |> D.delete(3)
        |> D.delete(5)

      refute D.has_key?(dict, 3)
      refute D.has_key?(dict, 5)
      assert D.to_list(dict) == [{1, 1}, {2, 2}, {4, 4}]
    end

    test "equal?/2 works across different shapes" do
      dict1 = D.from_list([{2, :b}, {1, :a}, {3, :c}])
      dict2 = D.from_list([{3, :c}, {1, :a}, {2, :b}])
      assert D.equal?(dict1, dict2)

      dict3 = D.put(dict2, 2, :other)
      refute D.equal?(dict1, dict3)
    end
  end

  describe "higher-order functions" do
    test "map/2 transforms keys and values" do
      dict = D.from_list([{1, 1}, {2, 2}, {3, 3}])

      mapped = D.map(dict, fn {k, v} -> {k * 2, v + 1} end)

      assert D.to_list(mapped) == [{2, 2}, {4, 3}, {6, 4}]
    end

    test "filter/2 keeps only matching pairs" do
      dict = D.from_list([{1, 1}, {2, 3}, {4, 5}, {5, 6}])

      filtered = D.filter(dict, fn {k, v} -> rem(k + v, 2) == 0 end)

      assert D.to_list(filtered) == [{1, 1}]
    end

    test "foldl/3 and foldr/3 traverse in order" do
      dict = D.from_list([{2, 2}, {1, 1}, {3, 3}])
      fun = fn pair, acc -> [pair | acc] end

      assert D.foldl(dict, [], fun) == Enum.reduce(D.to_list(dict), [], fun)

      assert D.foldr(dict, [], fun) ==
               Enum.reduce(Enum.reverse(D.to_list(dict)), [], fun)
    end
  end

  describe "monoid laws (examples)" do
    test "identity" do
      dict = D.from_list([{2, 2}, {1, 1}])
      assert D.equal?(dict, D.mappend(dict, D.empty()))
      assert D.equal?(dict, D.mappend(D.empty(), dict))
    end

    test "associativity" do
      a = D.from_list([{1, :a}])
      b = D.from_list([{1, :b}, {2, :c}])
      c = D.from_list([{3, :d}])

      left = D.mappend(a, D.mappend(b, c))
      right = D.mappend(D.mappend(a, b), c)

      assert D.equal?(left, right)
    end
  end

  ## Property-based tests

  defp gen_pairs do
    list_of({integer(), integer()})
  end

  test "property: monoid identity" do
    check all(pairs <- gen_pairs()) do
      dict = D.from_list(pairs)
      assert D.equal?(dict, D.mappend(dict, D.empty()))
      assert D.equal?(dict, D.mappend(D.empty(), dict))
    end
  end

  test "property: monoid associativity" do
    check all(
            p1 <- gen_pairs(),
            p2 <- gen_pairs(),
            p3 <- gen_pairs()
          ) do
      a = D.from_list(p1)
      b = D.from_list(p2)
      c = D.from_list(p3)

      left = D.mappend(a, D.mappend(b, c))
      right = D.mappend(D.mappend(a, b), c)

      assert D.equal?(left, right)
    end
  end

  test "property: put/get and delete/has_key? relationships" do
    check all(
            pairs <- gen_pairs(),
            key <- integer(),
            val <- integer()
          ) do
      dict = D.from_list(pairs)
      with_put = D.put(dict, key, val)

      assert D.get(with_put, key, :missing) == val
      assert D.has_key?(with_put, key)

      removed = D.delete(with_put, key)

      refute D.has_key?(removed, key)
      assert D.get(removed, key, :default) == :default
    end
  end

  test "property: map/2 matches mapping over to_list then rebuilding" do
    check all(pairs <- gen_pairs()) do
      dict = D.from_list(pairs)
      fun = fn {k, v} -> {k + 1, v * 2} end

      expected =
        dict
        |> D.to_list()
        |> Enum.map(fun)
        |> D.from_list()

      assert D.equal?(D.map(dict, fun), expected)
    end
  end

  test "property: filter/2 matches filtering the list representation" do
    check all(pairs <- gen_pairs()) do
      dict = D.from_list(pairs)
      pred = fn {k, v} -> rem(k, 2) == 0 or v < 0 end

      expected =
        dict
        |> D.to_list()
        |> Enum.filter(pred)
        |> D.from_list()

      assert D.equal?(D.filter(dict, pred), expected)
    end
  end

  test "property: foldl/3 and foldr/3 respect traversal order" do
    check all(pairs <- gen_pairs()) do
      dict = D.from_list(pairs)
      fun = fn pair, acc -> [pair | acc] end
      list = D.to_list(dict)

      assert D.foldl(dict, [], fun) == Enum.reduce(list, [], fun)
      assert D.foldr(dict, [], fun) == Enum.reduce(Enum.reverse(list), [], fun)
    end
  end
end
