# The configuration of Doctor. Each field that this file does not give keeps
# its default value.
%Doctor.Config{
  # Zigler makes this module for the NIF of `tools/expresso/gif/nif.ex`. It has
  # no source file, and Doctor stops when it cannot read the source of a module.
  ignore_modules: [Expresso.Gif.Nif.Manifest]
}
