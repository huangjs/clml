(defpackage :read-graph
  (:use :cl :excl :parse-number :util :vector :matrix)
  (:export #:node
           #:link
           #:node-id
           #:node-name
           #:node-links
           #:node-buff
           #:link-weight
           #:link-node1
           #:link-node2
           #:link-directed
           
           #:simple-graph
           #:simple-graph-series
           #:nodes
           #:links
           #:directed-p
           #:graphs
           
           #:read-graph
           #:do-graph-series
           #:read-graph-series
           #:make-simple-graph
           ))

(in-package :read-graph)

(defstruct (node (:conc-name node-))
  (id -1 :type fixnum)
  (name "" :type string)  
  (links nil)
  (buff nil))
(defmethod print-object ((obj node) stream)
  (print-unreadable-object (obj stream :type t :identity nil)
    (format stream "ID:~D, Name:~A" (node-id obj) (node-name obj))))

(defstruct (link (:conc-name link-))
  (weight 1d0 :type double-float)
  (node1 -1 :type fixnum)
  (node2 -1 :type fixnum)
  (directed nil) ;; nil (����) | t (�L�� node1 -> node2)
  )
(defmethod print-object ((obj link) stream)
  (print-unreadable-object (obj stream :type t :identity nil)
    (format stream "link~A, weight:~F"
            (if (link-directed obj) (format nil "\[~D -> ~D\]" (link-node1 obj) (link-node2 obj))
              (format nil "\[~D - ~D\]" (link-node1 obj) (link-node2 obj)))
            (link-weight obj))))

(defclass graph ()
  ((nodes :initform nil :initarg :nodes :accessor nodes)
   (node-hashtab :initform (make-hash-table :test #'eql)
                 :accessor node-hashtab)))
(defmethod print-object ((obj graph) stream)
  (print-unreadable-object (obj stream :type t :identity nil))
  (format stream "~&~D nodes" (length (nodes obj))))
(defclass simple-graph (graph) ;; �d�ݕt�������^�L���O���t
  ((links :initform nil :initarg :links :accessor links)
   (link-hashtab :initform (make-hash-table :test #'equal) :accessor link-hashtab)
   (directed-p :initform nil :initarg :directed-p 
               :accessor directed-p) ;; nil (����) | t (�L��)
   ))
(defmethod print-object ((obj simple-graph) stream)
  (call-next-method)
  (format stream "~&~D links" (length (links obj))))

  
;; �O���t�n��
(defclass simple-graph-series ()
  ((graphs :initform nil :initarg :graphs :accessor graphs)
   (graph-labels :initform nil :initarg :graph-labels :accessor graph-labels)))
(defmethod print-object ((obj simple-graph-series) stream)
  (print-unreadable-object (obj stream :type t :identity nil)
    (format stream "~D graphs" (length (graphs obj)))))

#||
(defclass multiple-graph (graph)  ;; ���d�O���t
  ((links :initarg :links :accessor links)))
(defclass bipartite-graph (graph)
  ;; �񕔃O���t
  ;; ...
  )
||#

(defmethod get-node ((gr simple-graph) id &optional (name ""))
  (assert (integerp id))
  (let ((htab (node-hashtab gr)))
    (or (gethash id htab)
        (let ((node (make-node :id id :name name)))
          (push node (nodes gr))
          (setf (gethash id htab) node)))))
(defmethod get-link ((gr simple-graph) nid1 nid2 &key (weight 1d0))
  (assert (and (integerp nid1) (integerp nid2)))
  (let ((htab (link-hashtab gr))
        (directed (directed-p gr)))
    (or (gethash (cons nid1 nid2) htab)
        (unless directed (gethash (cons nid2 nid1) htab))
        (let ((n1 (get-node gr nid1))
              (n2 (get-node gr nid2))
              (link (make-link :weight weight
                               :node1 nid1 :node2 nid2
                               :directed directed)))
          (push link (node-links n1))
          (push link (node-links n2))
          (push link (links gr))
          (setf (gethash (cons nid1 nid2) htab) link)))))

;; read-graph
;; �O���t�f�[�^��ǂݍ���
;; input: fname
;;        format, :sexp | :edgelist, �L�q�`��
;;        directed, nil | t, �������L����
;;        external-format
;; output: <graph>
;; - :sexp �`���̓m�[�h�����X�g�Ɨאڍs�񃊃X�g�ō\�������B
;;   �m�[�h�����X�g�� string �� list
;;   e.g. ("foo" "bar" "baz")
;;   �אڍs�񃊃X�g�͊e�v�f����̃��X�g�ł���悤�ȃ��X�g
;;   e.g. ((0.0 7.0 9.0)
;;         (7.0 0.0 10.0)
;;         (9.0 10.0 0.0))
;; - :edgelist �`���̓m�[�h���p�[�g�ƕӃp�[�g�ō\�������B
;;   �m�[�h���p�[�g�ƕӃp�[�g�͋�s�ŕ��������B
;;   �m�[�h���p�[�g�ł͊e�s��
;;   ID ���O
;;   �ł���B
;;   e.g.
;;   1 foo
;;   2 bar
;;   3 baz
;;   ID �� 1 ���珸���̘A�ԂłȂ���΂Ȃ�Ȃ��B
;;   �Ӄp�[�g�ł͊e�s��
;;   �m�[�hID1 �m�[�hID2 �d��
;;   �ł���B
;;   e.g.
;;   1 2 10
;;   2 3
;;   �d�݂��w�肵�Ȃ��ꍇ�͏d�� 1 �ƂȂ�B
;;   directed �� t �Ȃ�L���O���t�ƂȂ�A������
;;   �m�[�hID1 -> �m�[�hID2 �Ɖ��߂����B
(defun read-graph (fname &key (format :sexp)
                              (directed nil)
                              (external-format :default)
                              (id-name-alist nil)
                              (labelp nil))
  (with-open-file (in fname :direction :input :external-format external-format)
    (%read-graph in :format format :directed directed :id-name-alist id-name-alist :labelp labelp)))
(defun %read-graph (stream &key (format :sexp)
                                (directed nil)
                                (id-name-alist nil)
                                (labelp nil)
                                (target-nodes nil))
  (ecase format
    (:sexp (read-graph-sexp stream :directed directed :id-name-alist id-name-alist :labelp labelp
                            :target-nodes target-nodes))
    (:edgelist (read-graph-edgelist stream :directed directed :id-name-alist id-name-alist 
                                    :labelp labelp :target-nodes target-nodes))
    (:csv (read-graph-csv stream :directed directed :id-name-alist id-name-alist :labelp labelp
                          :target-nodes target-nodes))))
;; :sexp
(defun read-graph-sexp (stream &key (directed nil) (id-name-alist nil) (labelp nil))
  (let ((id-name-alist (if id-name-alist id-name-alist (read-name-part-sexp stream))))
    (multiple-value-bind (adj-mat label) (read-matrix-part stream :labelp labelp)
      (when (and id-name-alist (or (not labelp) (and labelp label)))
        (let ((gr (make-simple-graph id-name-alist :adjacency-matrix adj-mat :directed directed)))
          (if labelp (values gr label) gr))))))
(defun read-name-part-sexp (stream)
  (loop with names = (read stream nil nil nil)
      for name in names
      for id from 1
      collect (cons id name)))
(defun read-matrix-part (stream &key (labelp nil))
  (let* ((label (when labelp (read stream nil nil nil)))
         (adj-mat-list (read stream nil nil nil))
         (size (length adj-mat-list)))
    (values (make-array `(,size ,size) :element-type 'double-float
                        :initial-contents adj-mat-list)
            label)))
;; :edgelist
(defun read-graph-edgelist (stream &key (directed nil) (id-name-alist nil) (labelp nil))
  (let ((id-name-alist (if id-name-alist id-name-alist (read-name-part-edgelist stream))))
    (multiple-value-bind (edgelist label) (read-edgelist-part stream :labelp labelp)
      (when (and id-name-alist (or (not labelp) (and labelp label)))
        (let ((gr (make-simple-graph id-name-alist :edgelist edgelist :directed directed)))
          (if labelp (values gr label) gr))))))
(defun read-name-part-edgelist (stream)
  (loop for i from 1
      for line = (read-line stream nil nil nil)
      while (not (nil-or-null-string-p line))
      as list = (delimited-string-to-list line #\Space)
      as id = (parse-integer (first list))
      as name = (second list)
      collect (progn (unless (eql i id) 
                       (error "invalid ID specification: ~A" line))
                     (cons id name))))
(defun read-edgelist-part (stream &key (labelp nil))
  (let ((label (when labelp (read-line stream nil nil nil))))
    (values (loop for line = (read-line stream nil nil nil)
                while (not (nil-or-null-string-p line))
                collect (parse-edge line))
            label)))
(defun nil-or-null-string-p (str) 
  (or (null str)
      (= 0 (length (remove #\Space str :test #'char-equal)))))
(defun parse-edge (line) ;; "nid1 nid2 weight"
  (let ((list (delimited-string-to-list line #\Space)))
    (cond ((= (length list) 2) ;; not weighted
           `(:nid1 ,(parse-integer (first list)) :nid2 ,(parse-integer (second list))
                   :weight 1d0))
          ((= (length list) 3) ;; weighted
           `(:nid1 ,(parse-integer (first list)) :nid2 ,(parse-integer (second list))
                   :weight ,(dfloat (parse-number (third list)))))
          (t (error "invalid edge specification: ~A" line)))))
;; :csv
(defun read-graph-csv (stream &key (directed nil) (id-name-alist nil) (labelp nil))
  (let ((id-name-alist (if id-name-alist id-name-alist (read-name-part-csv stream))))
    (multiple-value-bind (adj-mat label) 
        (read-matrix-part-csv stream (length id-name-alist) :labelp labelp)
      (when (and id-name-alist (or (not labelp) (and labelp label)))
        (let ((gr (make-simple-graph id-name-alist
                                     :adjacency-matrix adj-mat :directed directed)))
          (if labelp (values gr label) gr))))))
(flet ((parse-csv-line (stream)
         (let ((line (read-line stream nil nil nil)))
           (when (stringp line) (csv::parse-csv-string line)))))
  (defun read-name-part-csv (stream)
    (loop with names = (parse-csv-line stream)
        for name across names
        for id from 1
        collect (cons id name)))
  (defun read-matrix-part-csv (stream size &key (labelp nil))
    (assert (numberp size))
    (let ((label (when labelp (parse-csv-line stream)))
          (adj-mat-list 
           (loop repeat size
               as vals = (map 'list (lambda (str) (dfloat (parse-number str)))
                              (parse-csv-line stream))
               when vals collect vals)))
      (values (if adj-mat-list 
                  (make-array `(,size ,size) :element-type 'double-float
                              :initial-contents adj-mat-list)
                (make-array '(0 0) :element-type 'double-float))
              (when (arrayp label) (aref label 0))))))

;; read-graph-series �O���t�̌n���ǂݍ���
;; �n��f�[�^�̊e�O���t�ɂ̓��x�������邱�Ƃ�O��Ƃ���B
;; �n��f�[�^�L�q�`��
;; - :sexp �`���̏ꍇ
;;   �m�[�h�����X�g�Ɨאڍs�񃊃X�g�̊Ԃ�S�������̃��x���Ƃ��ēǂݍ��܂��
;;   e.g. ("foo" "bar" "baz")
;;        "12:00:00"
;;        ((0.0 7.0 9.0)
;;         (7.0 0.0 10.0)
;;         (9.0 10.0 0.0))
;;        "12:05:00"
;;        ((0.0 6.0 5.0)
;;         (6.0 0.0 2.0)
;;         (5.0 2.0 0.0))     
;;
;; - :edgelist �`���̏ꍇ
;;   �Ӄp�[�g�̈�ԍŏ��̍s�����x��������Ƃ��ēǂݍ��܂��B
;;   e.g. 1 foo
;;        2 bar
;;        3 baz
;;
;;        12:00:00
;;        1 2 7
;;        1 3 9
;;        2 3 10
;;
;;        12:05:00
;;        1 2 6
;;        1 3 5
;;        2 3 2
;; - :csv �`���̏ꍇ
;;   :sexp�̊e�s��CSV�`���ł���悤�Ȃ���
;;   e.g. "foo","bar","baz"
;;        "12:00:00"          
;;        0.0,7.0,9.0      
;;        7.0,0.0,10.0    
;;        9.0,10.0,0.0    
;;        "12:05:00"      
;;        0.0,6.0,5.0     
;;        6.0,0.0,2.0     
;;        5.0,2.0,0.0
(defun read-graph-series (fname &key (format :sexp) (directed nil) (external-format :default)
                                     (start 0) (end nil)
                                     (start-label nil)
                                     (end-label nil)
                                     (target-labels nil)
                                     (target-nodes nil))
  (with-open-file (in fname :direction :input :external-format external-format)
    (%read-graph-series in :format format :directed directed :start start :end end
                        :start-label start-label :end-label end-label
                        :target-labels target-labels
                        :target-nodes target-nodes)))

(defmacro do-graph-series (((gr label) stream 
                            &key (format :sexp) (directed nil) (start 0) (end nil)
                                 (start-label nil) (end-label nil)
                                 (target-labels nil)
                                 (target-nodes nil))
                           &body body)
  "Repeatedly call BODY on Graph-Series stream STREAM, binding
   GR and LABEL to a class SIMPLE-GRAPH and the label string."
  `(let ((label-status (if (null ,start-label) :in-range :cont)))
     (flet ((in-range-p (label i start end start-label end-label target-labels)
              (cond (target-labels (if (member label target-labels :test #'equal) :in-range :cont))
                    ((or start-label end-label)
                     (cond ((equal start-label label) (setf label-status :in-range))
                           ((equal end-label label) (setf label-status :fin) :in-range)
                           (t label-status)))
                    ((and (numberp start) (numberp end)) (cond ((and (<= start i) (< i end)) :in-range)
                                                               ((<= end i) :fin)
                                                               (t :cont)))
                    ((numberp start) (if (<= start i) :in-range :cont))
                    ((numberp end) (if (< i end) :in-range :fin))
                    (t :in-range))))
       (loop with id-name-alist = (ecase ,format
                                    (:sexp (read-name-part-sexp ,stream))
                                    (:edgelist (read-name-part-edgelist ,stream))
                                    (:csv (read-name-part-csv ,stream)))
           for i from 0
           do (multiple-value-bind (,gr ,label)
                  (%read-graph ,stream :format ,format :directed ,directed 
                               :id-name-alist id-name-alist :labelp t
                               :target-nodes ,target-nodes)
                (unless ,gr (loop-finish))
                (let ((in-range-p (in-range-p ,label i ,start ,end ,start-label 
                                              ,end-label ,target-labels)))
                  (cond ((eq in-range-p :in-range) ,@body)
                        ((eq in-range-p :fin) (loop-finish)))))))))
  
(defun %read-graph-series (stream &key (format :sexp) (directed nil) (start 0) (end nil)
                                       (start-label nil) (end-label nil)
                                       (target-labels nil)
                                       (target-nodes nil))
  (let (graphs graph-labels)
    (do-graph-series ((gr label) stream
                                 :format format :directed directed :start start :end end
                                 :start-label start-label :end-label end-label
                                 :target-labels target-labels
                                 :target-nodes target-nodes)
      (push gr graphs)
      (push label graph-labels))
    (make-instance 'simple-graph-series
      :graphs (reverse graphs)
      :graph-labels (reverse graph-labels))))

;; simple-graph �I�u�W�F�N�g�����
;; input: id-name-alist, <list cons integer string>, �m�[�h�� ID �� ���O �� alist
;;        adjacency-matrix, (�m�[�h��)*(�m�[�h��)�̍s��Ai �Ԗڂ̍s����ї�̓m�[�hID�ɑΉ�
;;        edgelist, �e�v�f�� plist = (:nid1 * :nid2 * :weight *) �� list
;;        directed, nil | t
;; output: <simple-graph>
;; ID �� ���̐��� �Ō��Ԃ͂Ȃ��B
(defun make-simple-graph (id-name-alist &key (adjacency-matrix nil)
                                             (edgelist nil)
                                             (directed nil))
  (let ((gr (make-instance 'simple-graph :directed-p directed)))
    (loop for i from 1
        for (id . name) in (sort (copy-list id-name-alist) #'< :key #'car)
        do (progn (unless (eql i id)
                    (error "invalid ID Name specification: ~A" (cons id name)))
                  (get-node gr id name)))
    (make-links-adj gr adjacency-matrix)
    (make-links-edge gr edgelist)))
(defun make-links-adj (gr mat)
  (let ((n (length (nodes gr))))
    (when (and (typep mat 'dmat)
               (equal (list n n) (array-dimensions mat)))
      (loop for col below n
          as nid2 = (1+ col)
          do (loop for row below (if (directed-p gr) n (1+ col))
                 as nid1 = (1+ row)
                 as val = (aref mat col row)
                 unless (or (zerop val) (eql nid2 nid1))
                 do (get-link gr nid1 nid2 :weight val))))
    gr))
(defun make-links-edge (gr edgelist)
  (loop for edge in edgelist
      do (destructuring-bind (&key nid1 nid2 weight &allow-other-keys) edge
           (get-link gr nid1 nid2 :weight weight))
      finally (return gr)))
