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

;; more or less public vars (it's discouraged to set them globally)
(defvar *accessor-name-package* nil
  "A package, or :slot-name means the home-package of the slot-name symbol and nil means *package*")
(defvar *accessor-name-transformer* 'default-accessor-name-transformer)
(defvar *automatic-accessors-p* #t)

;; these control whether the respective names should be exported from *package* (which is samples at macroexpan time)
(defvar *export-class-name-p* nil)
(defvar *export-accessor-names-p* nil)
(defvar *export-slot-names-p* nil)

(defun default-initarg-name-transformer (name definition)
  (declare (ignorable definition))
  (concatenate-symbol name #.(symbol-package :asdf)))

(defvar *initarg-name-transformer* 'default-initarg-name-transformer)
(defvar *automatic-initargs-p* #t)

(defvar *allowed-slot-definition-properties* (list :documentation :type :reader :writer :allocation)
  "Holds a list of keywords that are allowed in slot definitions (:accessor and :initarg is implicitly included) .")

;; expand-time temporary dynamic vars
(defvar *accessor-names*)
(defvar *slot-names*)

(define-condition defclass-star-style-warning (simple-condition style-warning)
  ())

(defun style-warn (datum &rest args)
  (warn 'defclass-star-style-warning :format-control datum :format-arguments args))

(defun process-slot-definition (definition)
  (unless (consp definition)
    (setf definition (list definition)))
  (let ((name (pop definition))
        (initform 'missing)
        (entire-definition definition))
    (push name *slot-names*)
    (when (oddp (length definition))
      (setf initform (pop definition))
      (setf entire-definition definition)
      (when (eq initform :unbound)
        (setf initform 'missing)))
    (assert (eq (getf definition :initform 'missing) 'missing) ()
            ":initform is not allowed by the defclass-star syntax, the initform is taken from the first element of odd length slot definitions.")
    (assert (every #'keywordp (loop for el :in definition :by #'cddr
                                    collect el))
            () "Found non-keywords in ~S" definition)
    (let ((accessor (getf definition :accessor 'missing))
          (initarg (getf definition :initarg 'missing))
          (unknown-keywords))
      (remf-keywords definition :accessor :initform :initarg)
      (setf unknown-keywords (loop for el :in definition :by #'cddr
                                   unless (member el *allowed-slot-definition-properties*)
                                   collect el))
      (when unknown-keywords
        (style-warn "Unexpected properties in slot definition ~S. The unexpected elements are ~S. ~%~
                     To avoid this warning (pushnew your-custom-keyword defclass-star:*allowed-slot-definition-properties*)"
                    entire-definition definition))
      (prog1
          (append (list name)
                  (unless (eq initform 'missing)
                    (list :initform initform))
                  (if (eq accessor 'missing)
                      (when *automatic-accessors-p*
                        (setf accessor (funcall *accessor-name-transformer* name entire-definition))
                        (list :accessor accessor))
                      (list :accessor accessor))
                  (if (eq initarg 'missing)
                      (when *automatic-initargs-p*
                        (list :initarg (funcall *initarg-name-transformer* name entire-definition)))
                      (list :initarg initarg))
                  definition)
        (push accessor *accessor-names*)))))

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
         :automatic-initargs-p *automatic-initargs-p*
         :export-class-name-p *export-class-name-p*
         :export-accessor-names-p *export-accessor-names-p*
         :export-slot-names-p *export-slot-names-p*)))
    (values binding-names binding-values (nreverse clean-options))))

(macrolet ((def-star-macro (macro-name expand-to-name)
               `(defmacro ,macro-name (name direct-superclasses direct-slots &rest options)
                 (unless (eq (symbol-package name) *package*)
                   (style-warn "defclass* for ~A while its home package is not *package* (~A)"
                               (let ((*package* (find-package "KEYWORD")))
                                 (format nil "~S" name)) *package*))
                 (let ((*accessor-names* nil)
                       (*slot-names* nil))
                   (multiple-value-bind (binding-names binding-values clean-options)
                       (extract-options-into-bindings options)
                     (progv binding-names (mapcar #'eval binding-values)
                       (let ((result `(,',expand-to-name ,name
                                       ,direct-superclasses
                                       ,(mapcar 'process-slot-definition direct-slots)
                                       ,@clean-options)))
                         (if (or *export-class-name-p*
                                 *export-accessor-names-p*
                                 *export-slot-names-p*)
                             `(progn
                               ,result
                               (export (list ,@(mapcar (lambda (el)
                                                         (list 'quote el))
                                                       (append (when *export-class-name-p*
                                                                 (list name))
                                                               (when *export-accessor-names-p*
                                                                 (nreverse *accessor-names*))
                                                               (when *export-slot-names-p*
                                                                 (nreverse *slot-names*)))))
                                ,*package*))
                             result))))))))
  (def-star-macro defclass* defclass)
  (def-star-macro defcondition* define-condition))


