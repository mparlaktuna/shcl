(in-package :shcl-test.utility)
(in-suite utility)

(defparameter *value* 0)
(define-once-global test-global (incf *value*))

(def-test once-global (:compile-at :definition-time)
  (is (equal 1 test-global))
  (is (equal 1 test-global))
  (is (equal 1 *value*)))

(define-condition test-condition ()
  ())

(defun signals-test ()
  (signal 'test-condition))

(def-test hooks (:compile-at :definition-time)
  (define-hook test-hook)
  (add-hook test-hook 'test-condition)
  (is (signals 'test-condition (run-hook test-hook)))
  (remove-hook test-hook 'signals-test)
  (is (not (signals 'test-condition (run-hook test-hook))))
  (add-hook test-hook 'test-condition)
  (define-hook test-hook)
  (is (signals 'test-condition (run-hook test-hook))))

(def-test when-let-tests (:compile-at :definition-time)
  (is (not (when-let ((a (+ 1 2))
                      (b (format nil "asdf"))
                      (c (not 'not))
                      (d (error "This form shouldn't be evaluated")))
             (is nil))))
  (is (when-let ((a t)
                 (b t)
                 (c t))
        (is (eq a t))
        (is (eq b t))
        (is (eq c t))
        (and a b c))))

(def-test try-tests (:compile-at :definition-time)
  (is (eq 'foobar
          (try (progn (throw 'baz 123))
            (bap () 'xyz)
            (baz (value) (is (eq value 123)) 'foobar)))))

(def-test iterator-tests (:compile-at :definition-time)
  (let* ((vector #(1 2 3 4 5))
         (list '(a b c d e))
         (seq (fset:seq 'q 'w 'e 'r))
         (vector-iterator (vector-iterator vector))
         (list-iterator (list-iterator list))
         (generic-iterator (iterator seq)))
    (is (equal (coerce (iterator-values vector-iterator) 'list)
               (coerce vector 'list)))
    (is (equal (coerce (iterator-values list-iterator) 'list)
               list))
    (is (equal (coerce (iterator-values generic-iterator) 'list)
               (fset:convert 'list seq)))))

(def-test lookahead-iterator-tests (:compile-at :definition-time)
  (let* ((count 5)
         (iter (make-iterator (:type 'lookahead-iterator)
                 (when (equal 0 count)
                   (stop))
                 (decf count)))
         fork)
    (is (equal 5 count))
    (is (equal 4 (peek-lookahead-iterator iter)))
    (is (equal 4 count))
    (setf fork (fork-lookahead-iterator iter))
    (is (equal 4 (peek-lookahead-iterator fork)))
    (is (equal 4 (peek-lookahead-iterator iter)))
    (is (equal 4 count))
    (is (equal 4 (next iter)))
    (is (equal 3 (next iter)))
    (is (equal 2 (next iter)))
    (is (equal 2 count))
    (is (equal 4 (peek-lookahead-iterator fork)))
    (is (equal 2 count))
    (is (equal 4 (next fork)))
    (is (equal 3 (next fork)))
    (is (equal 2 count))
    (is (equal 1 (next iter)))
    (is (equal 1 count))
    (move-lookahead-to fork iter)
    (is (equal 0 (next iter)))
    (is (equal 0 count))
    (is (equal nil (next iter)))
    (is (equal 0 count))
    (is (equal 0 (next fork)))
    (is (equal 0 count))
    (is (equal nil (next fork)))
    (is (equal 0 count))))
