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

(defpackage :shcl/core/exit-info
  (:use :common-lisp :shcl/core/utility :shcl/core/posix)
  (:export
   #:exit-info #:exit-info-p #:exit-info-true-p #:exit-info-false-p
   #:invert-exit-info #:make-exit-info #:truthy-exit-info #:falsey-exit-info
   #:internal-error-exit-info #:exit-info-code))
(in-package :shcl/core/exit-info)

(optimization-settings)

(defclass exit-info ()
  ((pid
    :reader exit-info-pid
    :initform nil
    :initarg :pid
    :documentation
    "The pid of the process this object describes.")
   (exit-status
    :reader exit-info-exit-status
    :initform nil
    :initarg :exit-status
    :documentation
    "The exit code the process provided.")
   (exit-signal
    :reader exit-info-exit-signal
    :initform nil
    :initarg :exit-signal
    :documentation
    "The signal that caused the process to exit.")
   (stop-signal
    :reader exit-info-stop-signal
    :initform nil
    :initarg :stop-signal
    :documentation
    "The signal that caused the process to stop."))
  (:documentation
   "An object containing useful information about a process"))

(defun exit-info-p (thing)
  "Returns non-nil iff the given object is an `exit-info'."
  (typep thing 'exit-info))

(defmethod print-object ((exit-info exit-info) stream)
  (print-unreadable-object (exit-info stream :type t)
    (with-slots (pid exit-status exit-signal stop-signal) exit-info
      (let ((things (make-extensible-vector)))
        (when pid
          (vector-push-extend (cons :pid pid) things))
        (when exit-status
          (vector-push-extend (cons :exit-status exit-status) things))
        (when exit-signal
          (vector-push-extend (cons :exit-signal exit-signal) things))
        (when stop-signal
          (vector-push-extend (cons :stop-signal stop-signal) things))
        (loop :while (< 1 (length things)) :do
           (let ((pair (vector-pop things)))
             (format stream "~A ~A " (car pair) (cdr pair))))
        (let ((pair (vector-pop things)))
          (format stream "~A ~A" (car pair) (cdr pair)))))))

(defun exit-info-true-p (exit-info)
  "Given an exit info, return t iff the program exited successfully."
  (with-slots (exit-status exit-signal stop-signal) exit-info
    (labels ((okay (value) (or (null value) (zerop value))))
      (and (okay exit-status)
           (okay exit-signal)
           (okay stop-signal)))))

(defun exit-info-false-p (exit-info)
  "Given an exit info, return t iff the program didn't exit
sucesfully."
  (not (exit-info-true-p exit-info)))

(defun invert-exit-info (exit-info)
  "Given an exit info, produce a similar info that indicates the logical inverse."
  (if (exit-info-true-p exit-info)
      (make-exit-info :exit-status 1)
      (make-exit-info :exit-status 0)))

(defun exit-info-code (exit-info)
  "Turn an exit-info into an integer."
  (with-slots (exit-status exit-signal stop-signal) exit-info
    (+ (if exit-status exit-status 0)
       (if exit-signal exit-signal 0)
       (if stop-signal stop-signal 0))))

(defun make-exit-info (&key pid exit-status exit-signal stop-signal)
  "Produce an exit info that incorperates the given information."
  (make-instance 'exit-info :pid pid :exit-status exit-status :exit-signal exit-signal :stop-signal stop-signal))

(defun truthy-exit-info ()
  "Produce an exit-info that indicates success"
  (make-exit-info :exit-status 0))

(defun falsey-exit-info ()
  "Produce an exit-info that indicates failure"
  (make-exit-info :exit-status 1))

(defun internal-error-exit-info ()
  "Produce an exit-info that indicates shcl has failed in some way"
  (make-exit-info :exit-status 128))
