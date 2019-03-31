defmodule WyhashEx do
  @on_load :load_nifs

  def load_nifs do
    :erlang.load_nif('./c_src/wyhash_nif', 0)
  end

  def hash(_value) do
    raise "NIF hash/1 not implemented"
  end
end
