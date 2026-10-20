defmodule Examples.TreeDisk do
  use Expresso

  root __DIR__

  slide "the disk" do
    heading "Where the space goes"

    tree do
      title "The use of the disk, by folder"
      src "disk.csv"
      layout :left_right
      box [[width: 200, height: 80], [width: 240, height: 80]]
      value_format :bytes
      sort :value
      limit 2
      bar true
      highlight [branch("home"), branch("var")]
      whole_first true
    end
  end
end

Examples.TreeDisk
