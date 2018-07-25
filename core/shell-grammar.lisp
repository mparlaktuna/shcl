;; Copyright 2017 Bradley Jensen
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;;     http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.

(defpackage :shcl/core/shell-grammar
  (:use
   :common-lisp :shcl/core/parser :shcl/core/lexer :shcl/core/utility
   :shcl/core/iterator)
  (:import-from :shcl/core/advice #:define-advice #:define-advisable)
  (:export
   #:command-iterator
   ;; nonterminals
   #:complete-command #:command-list #:and-or #:and-or-tail :pipeline
   #:pipe-sequence #:pipe-sequence-tail #:command
   #:compound-command :subshell #:compound-list #:term
   #:term-sequence #:for-clause #:for-clause-range #:name-nt
   #:in-nt :words #:case-clause #:case-list-ns
   #:case-list :case-list-tail #:case-item-ns #:case-item #:pattern
   #:pattern-tail :if-clause #:else-part #:while-clause
   #:until-clause #:function-definition :function-body #:fname
   #:brace-group #:do-group #:simple-command #:cmd-name :cmd-word
   #:cmd-prefix #:cmd-prefix-tail #:cmd-suffix
   #:cmd-suffix-tail :redirect-list #:redirect-list-tail
   #:io-redirect #:io-file #:filename :io-source #:io-here #:here-end
   #:newline-list :linebreak #:separator-op #:separator
   #:sequential-sep :redirect #:fd-description
   #:condition #:body))
(in-package :shcl/core/shell-grammar)

(optimization-settings)

(defmacro define-terminals (&body terminals)
  (apply 'progn-concatenate
         (loop :for terminal :in terminals :collect
            (etypecase terminal
              (symbol
               `(define-terminal ,terminal))
              (cons
               `(define-terminal ,@terminal))))))

(define-terminals
  token a-word simple-word assignment-word name newline io-number and-if
  or-if dsemi dless dgreat lessand greatand lessgreat dlessdash
  clobber if-word then else elif fi do-word done case-word esac while until
  for lbrace rbrace bang in semi par pipe lparen rparen great less)

(define-nonterminal start
  parse-eof
  parse-complete-command)

(define-nonterminal complete-command
  (newline-list &optional complete-command)
  (command-list command-end))

(define-nonterminal command-end
  parse-eof
  parse-newline)

(define-nonterminal command-list
  (and-or &optional separator-op command-list))

(define-nonterminal and-or
  (pipeline and-or-tail))

(define-nonterminal and-or-tail
  (and-if linebreak pipeline and-or-tail)
  (or-if linebreak pipeline and-or-tail)
  ())

(define-nonterminal pipeline
  (bang pipe-sequence)
  parse-pipe-sequence)

(define-nonterminal pipe-sequence
  (command pipe-sequence-tail))

(define-nonterminal pipe-sequence-tail
  (pipe linebreak command pipe-sequence-tail)
  ())

(define-nonterminal command
  (compound-command &optional redirect-list)
  parse-function-definition
  parse-simple-command)

(define-nonterminal compound-command
  parse-brace-group
  parse-subshell
  parse-for-clause
  parse-case-clause
  parse-if-clause
  parse-while-clause
  parse-until-clause)

(define-nonterminal subshell
  (lparen compound-list rparen))

(define-nonterminal compound-list
  (linebreak term-sequence))

(define-nonterminal-class term ()
    (and-or
     separator))

(define-advisable parse-term-sequence (iter)
  (let ((continue-p t))
    (parser-repeat iter
      (cond
        (continue-p
         (parser-block
           (parser-value
            (make-instance 'term
                           'and-or (parse (parse-and-or iter))
                           'separator (parse
                                       (parser-handler-case iter
                                           (parse-separator iter)
                                         (t ()
                                            (setf continue-p nil)
                                            (parser-value nil))))))))
        (t
         (parser-error (make-instance 'unconditional-failure)))))))

(define-nonterminal for-clause
  (for name-nt linebreak for-clause-range (body parse-do-group)))

(define-nonterminal-class for-clause-range ()
    (in-nt
     words
     sequential-sep))

(define-advisable parse-for-clause-range (iter)
  (parser-choice iter
    (parser-block
      (parser-value
       (make-instance 'for-clause-range
                      'in-nt (parse (parse-in-nt iter))
                      'words (parser-repeat iter
                               (parse-a-word iter))
                      'sequential-sep (parse-sequential-sep iter))))
    (parser-value nil)))

(define-nonterminal name-nt
  (name)) ;; Apply rule 5 (need not be reflected in the grammar)

(define-nonterminal in-nt
  (in)) ;; Apply rule 6 (need not be reflected in the grammar)

(define-nonterminal case-clause
  (case-word a-word linebreak in-nt linebreak case-list esac)
  (case-word a-word linebreak in-nt linebreak case-list-ns esac)
  (case-word a-word linebreak in-nt linebreak esac))

(define-nonterminal case-list-ns
  (case-list case-item-ns)
  (case-item-ns))

(define-nonterminal case-list
  (case-item case-list-tail))

(define-nonterminal case-list-tail
  (case-item case-list-tail)
  ())

(define-nonterminal case-item-ns
  (pattern rparen linebreak)
  (pattern rparen compound-list linebreak)
  (lparen pattern rparen linebreak)
  (lparen pattern rparen compound-list linebreak))

(define-nonterminal case-item
  (pattern rparen linebreak dsemi linebreak)
  (pattern rparen compound-list dsemi linebreak)
  (lparen pattern rparen linebreak dsemi linebreak)
  (lparen pattern rparen compound-list dsemi linebreak))

(define-nonterminal pattern
  (a-word pattern-tail)) ;; Apply rule 4 (must be reflected in grammar)

(define-nonterminal pattern-tail
  (pipe a-word pattern-tail) ;; Do not apply rule 4 (but /bin/sh seems to?)
  ())

(define-nonterminal if-clause
  (if-word (condition parse-compound-list) then (body parse-compound-list) else-part))

(define-nonterminal else-part
  (elif (condition parse-compound-list) then (body parse-compound-list) else-part)
  (else (body parse-compound-list) fi)
  parse-fi)

(define-nonterminal while-clause
  (while (condition parse-compound-list) (body parse-do-group)))

(define-nonterminal until-clause
  (until (condition parse-compound-list) (body parse-do-group)))

(define-nonterminal function-definition
  (fname linebreak function-body))

(define-nonterminal function-body
  (compound-command redirect-list) ;; Apply rule 9 (need not be reflected in the grammar)
  (compound-command)) ;; Apply rule 9 (need not be reflected in the grammar)

(define-nonterminal-class fname ()
    (name
     lparen
     rparen))

(define-advisable parse-fname (iter)
  (parser-let
      ((name-lparen
        (parser-try iter
          (parser-let
              ((name (parse-name iter))
               (lparen (parse-lparen iter)))
            (parser-value (cons name lparen)))))
       (rparen (parse-rparen iter)))
    (parser-value
     (make-instance 'fname
                    'name (car name-lparen)
                    'lparen (cdr name-lparen)
                    'rparen rparen))))

(define-nonterminal brace-group
  (lbrace compound-list rbrace))

(define-nonterminal do-group
  (do-word compound-list done)) ;; Apply rule 6 (need not be reflected in the grammar)

(define-nonterminal simple-command
  (cmd-prefix &optional cmd-word cmd-suffix)
  (cmd-name &optional cmd-suffix))

;; Apply rule 7a
(deftype cmd-name ()
  "A type representing command names"
  `(and a-word (not reserved-word)))
(define-terminal cmd-name)

(define-nonterminal cmd-word
  parse-a-word) ;; Apply rule 7b (might need to be reflected in the grammar)

(define-nonterminal cmd-prefix
  (io-redirect cmd-prefix-tail)
  (assignment-word cmd-prefix-tail))

(define-nonterminal cmd-prefix-tail
  (io-redirect cmd-prefix-tail)
  (assignment-word cmd-prefix-tail)
  ())

(define-nonterminal cmd-suffix
  (io-redirect cmd-suffix-tail)
  (a-word cmd-suffix-tail))

(define-nonterminal cmd-suffix-tail
  (io-redirect cmd-suffix-tail)
  (a-word cmd-suffix-tail)
  ())

(define-nonterminal redirect-list
  (io-redirect redirect-list-tail))

(define-nonterminal redirect-list-tail
  (io-redirect redirect-list-tail)
  ())

(define-nonterminal-class io-redirect ()
    (io-number
     io-source))

(define-advisable parse-io-redirect (iter)
  (parser-choice iter
    (parse-io-file iter)
    (parse-io-here iter)
    (parser-block
      (parser-value
       (make-instance 'io-redirect
                      'io-number (parse (parse-io-number iter))
                      'io-source (parse
                                  (parser-choice iter
                                    (parse-io-file iter)
                                    (parse-io-here iter))))))))

(define-nonterminal io-file
  ((redirect parse-less) filename)
  ((redirect parse-lessand) (fd-description parse-simple-word))
  ((redirect parse-great) filename)
  ((redirect parse-greatand) (fd-description parse-simple-word))
  ((redirect parse-dgreat) filename)
  ((redirect parse-lessgreat) filename)
  ((redirect parse-clobber) filename))

(define-nonterminal filename
  parse-a-word) ;; Apply rule 2 (need not be reflected in grammar)

(define-nonterminal io-here
  (dless here-end)
  (dlessdash here-end))

(define-nonterminal here-end
  (a-word)) ;; Apply rule 3 (need not be reflected in grammar)

(define-nonterminal newline-list
  (newline &optional newline-list))

(define-nonterminal linebreak
  (newline-list)
  ())

(define-nonterminal separator-op
  parse-par
  parse-semi)

(define-nonterminal separator
  (separator-op linebreak)
  (newline-list))

(define-nonterminal sequential-sep
  (semi linebreak)
  (newline-list))

(defun command-iterator (token-iterator)
  "Given a `lookahead-iterator' that produces tokens, return an
iterator that produces shell syntax tree objects."
  (let ((iter (syntax-iterator #'parse-start token-iterator)))
    (make-iterator ()
      (do-iterator (value iter)
        (when (eq value :eof)
          (stop))
        (emit value))
      (stop))))

(defgeneric parse-shell (source))

(defmethod parse-shell ((s string))
  (parse-shell (make-string-input-stream s)))

(defmethod parse-shell ((s stream))
  (parse-shell (lookahead-iterator-wrapper (token-iterator s))))

(defmethod parse-shell ((iter lookahead-iterator))
  (next (command-iterator iter)))
