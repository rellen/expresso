# The tests of a command run only when the command is available.
missing =
  for {tag, variable, command} <- [{:ffmpeg, "FFMPEG", "ffmpeg"}, {:gifski, "GIFSKI", "gifski"}],
      System.find_executable(System.get_env(variable, command)) == nil,
      do: tag

ExUnit.start(exclude: missing)
