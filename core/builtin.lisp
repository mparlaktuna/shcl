(defpackage :shcl/core/builtin
  (:use :common-lisp :shcl/core/utility :shcl/core/fd-table :shcl/core/working-directory :shcl/core/environment)
  (:import-from :fset)
  (:import-from :alexandria)
  (:shadow #:dump-logs)
  (:export #:define-builtin #:lookup-builtin))
(in-package :shcl/core/builtin)

(optimization-settings)

(defparameter *builtin-table* (fset:empty-map)
  "A map from builtin name (string) to handler functions.")

(defmacro define-builtin (name (args) &body body)
  "Define a new shell builtin.

`name' should either be a symbol or a list of the
form (`function-name' `builtin-name') where `function-name' is a
symbol and `builtin-name' is a string.  If `name' is simply a symbol,
then the builtin name is the downcased symbol name."
  (when (symbolp name)
    (setf name (list name (string-downcase (symbol-name name)))))
  (destructuring-bind (function-sym string-form) name
    (multiple-value-bind (body-forms declarations doc-string) (alexandria:parse-body body :documentation t)
      `(progn
         (defun ,function-sym (,args)
           ,@(when doc-string (list doc-string))
           ,@declarations
           (with-fd-streams ()
             ,@body-forms))
         (setf *builtin-table* (fset:with *builtin-table* ,string-form ',function-sym))))))

(defun lookup-builtin (name)
  "Attempt to find the function which corresponds to the builtin with
the provided string name.

Returns nil if there is no builtin by the given name."
  (fset:lookup *builtin-table* name))

(define-builtin dump-logs (args)
  (declare (ignore args))
  (shcl/core/utility:dump-logs)
  0)

(define-builtin (builtin-cd "cd") (args)
  ;; Cut off command name
  (setf args (fset:less-first args))
  (when (zerop (fset:size args))
    (let ((home (env "HOME")))
      (when (zerop (length home))
        (format *error-output* "cd: Could not locate home")
        (return-from builtin-cd 1))

      (fset:push-last args home)))

  (cd (fset:last args))
  0)

(define-builtin pushd (args)
  (fset:pop-first args)
  (unless (equal 1 (fset:size args))
    (format *error-output* "Anything but 1 arg pushd is not implemented~%")
    (return-from pushd 1))

  (push-working-directory (fset:last args))
  0)

(define-builtin popd (args)
  (fset:pop-first args)
  (unless (equal 0 (fset:size args))
    (format *error-output* "popd takes no arguments~%")
    (return-from popd 1))

  (pop-working-directory)
  0)