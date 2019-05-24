#!/bin/bash

function fail() {
  echo -n -e '\e[1;31m[ERROR]\e[0m '
  echo "$1"
  exit 1
}

function do_run() {
  error=$(echo "$3" | ./minilisp 2>&1 > /dev/null)
  if [ -n "$error" ]; then
    echo FAILED
    fail "$error"
  fi

  result=$(echo "$3" | ./minilisp 2> /dev/null | tail -1)
  if [ "$result" != "$2" ]; then
    echo FAILED
    fail "$2 expected, but got $result"
  fi
}

function run() {
  echo -n "Testing $1 ... "
  # Run the tests twice to test the garbage collector with different settings.
  MINILISP_ALWAYS_GC= do_run "$@"
  MINILISP_ALWAYS_GC=1 do_run "$@"
  echo ok
}

# Basic data types
run integer 1 1
run integer -1 -1
run symbol a "'a"
run quote a "(quote a)"
run quote 63 "'63"
run quote '(+ 1 2)' "'(+ 1 2)"
run '+' 3 '(+ 1 2)'
run '+' -2 '(+ 1 -3)'
run list "(a b c)" "(list 'a 'b 'c)"

run 'literal list' '(a b c)' "'(a b c)"
run 'literal list' '(a b . c)' "'(a b . c)"

# Comments
run comment 5 "
  ; 2
  5 ; 3"

# Global variables
run define 7 '(define x 7) x'
run define 10 '(define x 7) (+ x 3)'
run define 7 '(define + 7) +'
run setq 11 '(define x 7) (setq x 11) x'
run setq 17 '(setq + 17) +'

# Conditionals
run if a "(if 1 'a)"
run if '()' "(if () 'a)"
run if a "(if 1 'a 'b)"
run if a "(if 0 'a 'b)"
run if a "(if 'x 'a 'b)"
run if b "(if () 'a 'b)"
run if c "(if () 'a 'b 'c)"

# Numeric comparisons
run = t '(= 3 3)'
run = '()' '(= 3 2)'

# Functions
run lambda '<function>' '(lambda (x) x)'
run lambda t '((lambda () t))'
run lambda 9 '((lambda (x) (+ x x x)) 3)'
run defun 12 '(defun double (x) (+ x x)) (double 6)'

# Lexical closures
run closure 3 '(defun call (f) ((lambda (var) (f)) 5))
  ((lambda (var) (call (lambda () var))) 3)'

run counter 3 '
  (define counter
    ((lambda (val)
       (lambda () (setq val (+ val 1)) val))
     0))
  (counter)
  (counter)
  (counter)'

# Macros
run macro 42 "
  (defmacro if-zero (x then) (list 'if (list '= x 0) then))
  (if-zero 0 42)"

run macro 7 '(defmacro seven () 7) ((lambda () (seven)))'

# test macroexpand*
run macroexpand-1 '(if (= x 0) (print x))' "
  (defmacro if-zero (x then) (list 'if (list '= x 0) then))
  (macroexpand-1 (if-zero x (print x)))"

run macroexpand '(if (= x 0) (print x))' "
  (defmacro if-zero (x then) (list 'if (list '= x 0) then))
  (macroexpand (if-zero x (print x)))"

run macroexpand-all '(if (= x 0) (print x))' "
  (defmacro if-zero (x then) (list 'if (list '= x 0) then))
  (macroexpand-all (if-zero x (print x)))"

run macroexpand-1 '(plus 3 4)' "
(defmacro plus (n1 n2) (list '+ n1 n2))
(defmacro p1 (p1 p2) (list 'plus p1 p2))
(macroexpand-1 (p1 3 4))"

run macroexpand '(+ 3 4)' "
(defmacro plus (n1 n2) (list '+ n1 n2))
(defmacro p1 (p1 p2) (list 'plus p1 p2))
(macroexpand (p1 3 4))"

run macroexpand-all '(+ 20 (+ 20 30))' "
(defmacro plus (n1 n2) (list '+ n1 n2))
(defmacro p1 (p1 p2) (list 'plus p1 p2))
(defmacro p2 (p1 p2) (list '+ p1 p2))
(defmacro calc (c1 c2) (list 'p1 c1 (list 'p2 c1 c2)))
(macroexpand-all (calc 20 30))
"
run macroexpand-1 '(p1 20 (p2 20 30))' "
(defmacro plus (n1 n2) (list '+ n1 n2))
(defmacro p1 (p1 p2) (list 'plus p1 p2))
(defmacro p2 (p1 p2) (list '+ p1 p2))
(defmacro calc (c1 c2) (list 'p1 c1 (list 'p2 c1 c2)))
(macroexpand-1 (calc 20 30))
"

run macroexpand '(+ 20 (p2 20 30))' "
(defmacro plus (n1 n2) (list '+ n1 n2))
(defmacro p1 (p1 p2) (list 'plus p1 p2))
(defmacro p2 (p1 p2) (list '+ p1 p2))
(defmacro calc (c1 c2) (list 'p1 c1 (list 'p2 c1 c2)))
(macroexpand (calc 20 30))
"

# Sum from 0 to 10
run recursion 55 '(defun f (x) (if (= x 0) 0 (+ (f (+ x -1)) x))) (f 10)'
