;; -*- mode: Lisp; Syntax: Common-Lisp; -*-
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

(in-package :defclass-star)

(enable-sharp-boolean-syntax)

(defmacro make-name-transformer (&rest elements)
  `(lambda (name definition)
    (declare (ignorable definition))
    (concatenate-symbol ,@(mapcar (lambda (el)
                                    (if (and (symbolp el)
                                             (string= (symbol-name el) "NAME"))
                                        'name
                                        el))
                                  elements))))

(defun default-accessor-name-transformer (name definition)
  (let ((type (getf definition :type))
        (package (if (packagep *accessor-name-package*)
                     *accessor-name-package*
                     (case *accessor-name-package*
                       (:slot-name (symbol-package name))
                       (:default *package*)
                       (t *package*)))))
    (if (eq type 'boolean)
        (let* ((name-string (string name))
               (last-char (aref name-string (1- (length name-string)))))
          (cond ((char-equal last-char #\p)
                 name)
                ((find #\- name-string)
                 (concatenate-symbol name "-P" package))
                (t (concatenate-symbol name "P" package))))
        (concatenate-symbol name "-OF" package))))

(defvar *accessor-name-package* nil ;; :slot-name
  ":slot-name means the home-package of the slot-name symbol, nil means *package*")
(defvar *accessor-name-transformer* 'default-accessor-name-transformer)
(defvar *automatic-accessors-p* #t)

(defun default-initarg-name-transformer (name definition)
  (declare (ignorable definition))
  (concatenate-symbol name #.(symbol-package :asdf)))

(defvar *initarg-name-transformer* 'default-initarg-name-transformer)
(defvar *automatic-initargs-p* #t)

;; TODO
;;(defvar *export-slot-names-p* #f)
;;(defvar *export-accessor-names-p* #f)

(defun process-slot-definition (definition)
  (unless (consp definition)
    (setf definition (list definition)))
  (let ((name (pop definition))
        (initform 'missing))
    (when definition
      (setf initform (pop definition))
      (when (eq initform :unbound)
        (setf initform 'missing)))
    (assert (evenp (length definition)) () "Expecting a valid property list instead of ~S; it's length is odd" definition)
    (assert (eq (getf definition :initform 'missing) 'missing) () ":initform is not allowed by the syntax")
    (let ((accessor (getf definition :accessor 'missing))
          (initarg (getf definition :initarg 'missing)))
      (remf-keywords definition :accessor :initform :initarg)
      (append (list name)
              (unless (eq initform 'missing)
                (list :initform initform))
              (if (eq accessor 'missing)
                  (when *automatic-accessors-p*
                    (list :accessor (funcall *accessor-name-transformer* name definition)))
                  (list :accessor accessor))
              (if (eq initarg 'missing)
                  (when *automatic-initargs-p*
                    (list :initarg (funcall *initarg-name-transformer* name definition)))
                  (list :initarg initarg))
              definition))))

(defun extract-options-into-bindings (options)
  (let ((binding-names)
        (binding-values)
        (clean-options))
    (macrolet ((rebinding-table (&rest args)
                 `(case (car option)
                   ,@(loop for (arg-name var-name) :on args :by #'cddr
                           collect `(,arg-name
                                     (assert (= (length option) 2))
                                     (push ',var-name binding-names)
                                     (push (second option) binding-values)))
                   (t (push option clean-options)))))
      (dolist (option options)
        (rebinding-table
         :accessor-name-package *accessor-name-package*
         :accessor-name-transformer *accessor-name-transformer*
         :automatic-accessors-p *automatic-accessors-p*
         :initarg-name-transformer *initarg-name-transformer*
         :automatic-initargs-p *automatic-initargs-p*)))
    (values binding-names binding-values (nreverse clean-options))))

(macrolet ((def-star-macro (macro-name expand-to-name)
               `(defmacro ,macro-name (name direct-superclasses direct-slots &rest options)
                 (multiple-value-bind (binding-names binding-values clean-options)
                     (extract-options-into-bindings options)
                   (progv binding-names (mapcar 'eval binding-values)
                     `(,',expand-to-name ,name
                       ,direct-superclasses
                       ,(mapcar 'process-slot-definition direct-slots)
                       ,@clean-options))))))
  (def-star-macro defclass* defclass)
  (def-star-macro defcondition* define-condition))


