defmodule Expresso.Lexers.Elisp do
  @moduledoc """
  The Makeup lexer of Emacs Lisp

  A special form or a macro, such as `defun` or `let`, is a keyword, and a
  common function, such as `mapcar`, is a built-in. A character, such as
  `?a` or `?\\n`, is a string. See `Expresso.Lexers.Lisp` for the rules
  that the Lisps share.
  """

  use Expresso.Lexer, language: :elisp

  symbol = [
    ?a..?z,
    ?A..?Z,
    ?0..?9,
    ?-,
    ?_,
    ?+,
    ?*,
    ?/,
    ?<,
    ?>,
    ?=,
    ?!,
    ??,
    ?$,
    ?%,
    ?&,
    ?~,
    ?^,
    ?.
  ]

  character =
    string("?")
    |> choice([string("\\") |> utf8_string([], 1), utf8_string([not: ?\s, not: ?\n], 1)])
    |> lexeme()
    |> token(:string_char)

  definers =
    ~w(defun defmacro defvar defvar-local defcustom defconst defgroup defface defsubst defalias
       cl-defun cl-defmacro cl-defstruct cl-defgeneric cl-defmethod define-minor-mode
       define-derived-mode use-package)

  keywords =
    definers ++
      ~w(let let* if when unless cond progn prog1 prog2 lambda setq setq-local setf while dolist
         dotimes and or not require provide interactive save-excursion save-restriction
         save-match-data condition-case unwind-protect catch throw ignore-errors pcase pcase-let
         cl-loop cl-case quote function with-eval-after-load with-current-buffer with-temp-buffer
         declare-function eval-when-compile eval-and-compile)

  builtins =
    ~w(car cdr cons list append mapcar mapc message format concat funcall apply nth length null
       eq eql equal add-hook remove-hook add-to-list global-set-key define-key keymap-set
       buffer-string point goto-char insert string-match match-string error user-error
       plist-get alist-get assoc member delete remove reverse sort number-to-string
       string-to-number)

  deflexer(
    Expresso.Lexers.Lisp.rules(
      symbol: symbol,
      definers: definers,
      quotes: ["'", "`", ",@", ",", "#'"],
      extra: [character]
    ),
    Map.merge(
      Map.merge(words(keywords, :keyword), words(~w(+ - * / < > = /= <= >= 1+ 1-), :operator)),
      Map.merge(words(builtins, :name_builtin), words(~w(nil t), :keyword_constant))
    )
  )
end
