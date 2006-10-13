;; -*- mode: Lisp; Syntax: Common-Lisp; Package: computed-class; -*-
;;;
;;; Copyright (c) 2006 by the authors.
;;;
;;; Permission is hereby granted, free of charge, to any person obtaining a copy 
;;; of this software and associated documentation files (the "Software"), to deal 
;;; in the Software without restriction, including without limitation the rights 
;;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
;;; copies of the Software, and to permit persons to whom the Software is furnished 
;;; to do so, subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be included in 
;;; all copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
;;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
;;; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
;;; IN THE SOFTWARE.

(in-package :cl-user)

(defpackage #:defclass-star.system
  (:use :cl :asdf))

(in-package #:defclass-star.system)

(defsystem :defclass-star
  :version "0.1"
  :author ("Attila Lendvai <attila.lendvai@gmail.com>")
  :maintainer ("Attila Lendvai <attila.lendvai@gmail.com>")
  :licence "BSD"
  :description "A defclass* to simplify life."
  :components
  ((:file "package")
   (:file "duplicates" :depends-on ("package"))
   (:file "defclass-star" :depends-on ("duplicates"))))

(defsystem :defclass-star.test
  :description "Tests for the defclass-star system."
  :depends-on (:defclass-star :fiveam)
  :components
  ((:file "test")))

(defmethod perform ((op test-op) (system (eql (find-system :defclass-star))))
  (operate 'load-op :defclass-star.test)
  (funcall (read-from-string "5am:run!")))

(defmethod operation-done-p ((op test-op) (system (eql (find-system :defclass-star))))
  nil)
