defmodule Expresso.Component do
  @moduledoc """
  The component function of Temple for the element modules

  Temple compiles `c/2` to a call of `component/3`. `use Temple.Component`
  defines that function and two helpers in the module that uses it. The
  element modules import them from this module, so that each element module
  does not define its own copy. This module depends on no other module of
  Expresso.
  """

  use Temple.Component
end
