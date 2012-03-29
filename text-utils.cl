(defpackage :text-utilities
  (:nicknames :text-utils)
  (:use :common-lisp :hjs.learn.read-data)
  (:export :calculate-string-similarity
           :equivalence-clustering
           ))

(in-package :text-utilities)

;;; ������̗ގ��x���Z�o����
(defun calculate-string-similarity (str1 str2 &key (type :lev)) ;; :lev | :lcs
  (ecase type
    (:lev (calculate-levenshtein-similarity str1 str2))
    (:lcs (calculate-lcs-similarity str1 str2))))

;;;; levenshtein����(�ҏW����)���v�Z����B
;;; levenshtein����(�ҏW����)�͓�̕�����̗ގ��x�𐔒l���������́B
;;; �����̑}��/�폜/�u���ň���𑼕��ɕό`���邽�߂̍ŏ��菇�񐔂𐔂�������
;;; ���镶����str1��i�Ԗڂ܂ł̕���������Ƃ��镶����str2�̕�����2��j�Ԗڂ܂ł̕���������̊Ԃ�levenshtein������LD(i,j)�Ƃ���ƈȉ��̑Q���������藧�B
;;; LD(i,j) = LD(i-1, j) + 1 (�}��)
;;; LD(i,j) = LD(i, j-1) + 1 (�폜)
;;; LD(i,j) = LD(i-1, j-1) + c (c�͎��̕����������Ȃ�0, �Ⴆ��1�B�u��)
;;; LD(0,0) = 0, LD(i,0) = i, LD(0,j) = j (��_) 
;;; �啶���������͋�ʂ��Ȃ�
;;; ���� str1(������1) str2(������2)
(defun calculate-levenshtein-distance (str1 str2)
  (declare (optimize (speed 3))
           (type (simple-array character (*)) str1 str2))
  (let ((strlen1 (length str1))
        (strlen2 (length str2)))
    (declare (type (integer 0 #.most-positive-fixnum) strlen1 strlen2))
    (let ((len1 (1+ strlen1))
          (len2 (1+ strlen2)))
      (declare (type (integer 0 #.most-positive-fixnum) len1 len2))
      (let ((d (make-array (list len1 len2) :element-type '(integer 0 #.most-positive-fixnum) :initial-element 0)))
        (dotimes (i len1)
          (setf (aref d i 0) i))        ; ��_
        (dotimes (j len2)
          (setf (aref d 0 j) j))        ; ��_
        (dotimes (i strlen1)
          (dotimes (j strlen2)
            (declare (type (integer 0 #.most-positive-fixnum) i j))
            (let ((c (if (char-equal (char str1 i)
                                     (char str2 j))
                         0
                       1))
                  (ni (1+ i))
                  (nj (1+ j)))
              (declare (type (integer 0 1) c)
                       (type (integer 0 #.most-positive-fixnum) ni nj))
              (setf (aref d ni nj)
                (min (the (integer 0 #.most-positive-fixnum) (1+ (aref d i nj)))
                     (the (integer 0 #.most-positive-fixnum) (1+ (aref d ni j)))
                     (the (integer 0 #.most-positive-fixnum) (+ (aref d i j) c)))))))
      
        #+ignore
        (loop for i from 1 to (1- len1)
            do (loop for j from 1 to (1- len2)
                   do (let ((c (if (char-equal (char str1 (1- i))
                                               (char str2 (1- j)))
                                   0
                                 1)))
                        (setf (aref d i j)
                          (min (1+ (aref d (1- i) j))
                               (1+ (aref d i (1- j)))
                               (+ (aref d (1- i) (1- j)) c))))))
      
        (aref d strlen1 strlen2)
        ))))

;; �Œ����ʕ����n�񒷁iLCS��, longest common subsequence�j�����߂�B
;; ������str1�̕�����(�A�����Ă���K�v�͂Ȃ����A�����͕ύX�ł��Ȃ�)�ƕ�����str2�̕�����̒��ŗ����ɋ��ʂɊ܂܂����̂����ʕ�����B
;; ���ʕ�����̒��ł����Ƃ��������̂��Œ����ʕ�����Ƃ����B
;; LCS�̒�����(���Ƃ̕�����̒����Ɣ�r����)������Ηގ�����������ƂȂ�B
;; ������str1�̂���i�Ԗڂ܂ł̕�����Xi�ƕ�����str2�̂���j�Ԗڂ܂ł̕�����Yi��LCS����LCS(i,j)�Ƃ���B
;; (a) Xi��Yi�̍Ō�̕����������ł���ꍇ
;;     LCS(i,j) = LCS(i-1, j-1) + 1
;; (b) Xi��Yi�̍Ō�̕������ق��Ă����ꍇ
;;     LCS(i,j) = max(LCS(i,j-1), LCS(i-1,j))
;; i=0�܂���j=0�̂Ƃ�LCS(i,j)=0
;; �啶���������͋�ʂ��Ȃ�
(defun calculate-lcs-distance (str1 str2)
  (declare (optimize (speed 3))
           (type (simple-array character (*)) str1 str2))
  (let ((strlen1 (length str1))
        (strlen2 (length str2)))
    (declare (type (integer 0 #.most-positive-fixnum) strlen1 strlen2))
    (let ((len1 (1+ strlen1))
          (len2 (1+ strlen2)))
      (declare (type (integer 0 #.most-positive-fixnum) len1 len2))
      (let ((d (make-array (list len1 len2) :element-type '(integer 0 #.most-positive-fixnum) :initial-element 0)))
        (dotimes (i strlen1)
          (dotimes (j strlen2)
            (declare (type (integer 0 #.most-positive-fixnum) i j))
            (let ((ni (1+ i))
                  (nj (1+ j)))
              (if (char-equal (char str1 i)
                              (char str2 j))
                  (setf (aref d ni nj)
                    (1+ (aref d i j)))
                (setf (aref d ni nj)
                  (max (aref d i nj)
                       (aref d ni j)))))))
        (aref d strlen1 strlen2)))))

;; ���[�x���V���^�C���^LCS�����́A�l��������̒����Ɉ��������Ă��܂����߁A
;; �ގ��x�Ƃ��Ĉ����ɂ͐��K�����Ă��K�v������B
#+ignore
(defun calculate-levenshtein-similarity (str1 str2)
  (declare (optimize speed) (type (simple-array character (*)) str1 str2))
  (- 1.0 (/ (* 2.0 (the integer (calculate-levenshtein-distance str1 str2)))
            (+ (the fixnum (length str1)) (the fixnum (length str2))))))
(defun calculate-levenshtein-similarity (str1 str2)
  (declare (optimize speed) (type (simple-array character (*)) str1 str2))
  (- 1.0 (/ (the integer (calculate-levenshtein-distance str1 str2))
            (max (the fixnum (length str1)) (the fixnum (length str2))))))

(defun calculate-lcs-similarity (str1 str2)
  (declare (optimize speed) (type (simple-array character (*)) str1 str2))
  (/ (* 2.0 (the integer (calculate-lcs-distance str1 str2)))
     (+ (the fixnum (length str1)) (the fixnum (length str2)))))

;;������Ŗ��w���ꂽ�ΏۊԂɗ^����ꂽ���l�֌W����A���l�ނ��`�������X�g�ŕԂ��B
(defun equivalence-clustering (data-vector)
  "Based on Knuth's equivalence clustering algorithm"
  (when (= 0 (length data-vector))
    (return-from equivalence-clustering nil))
  ;;(assert (<= 1 (length data-vector)))
  (let* ((string-index-table 
	  (loop 
	      for i of-type fixnum below (length data-vector)
	      with table = (make-hash-table :test #'equal)
	      as row = (svref data-vector i)
	      as string0 = (svref row 0)
	      as string1 = (svref row 1)
	      do (setf (gethash string0 table) 0)
		 (setf (gethash string1 table) 0)
	      finally (return table)))
	 (n (hash-table-count string-index-table))
	 (string-array (coerce (loop for key being the hash-keys in string-index-table collect key) 'vector))
	 (class-id-array (coerce (loop for i of-type fixnum below n collect i) 'vector))
	 (label-index (1- (length (svref data-vector 0))))
	 (a-array)
	 (b-array))
    
    (loop 
	for i of-type fixnum below n
	do (setf (gethash (svref string-array i) string-index-table) i))
    
    (multiple-value-setq (a-array b-array)
      (loop
	  for row across data-vector
	  as label = (svref row label-index)
	  if (= 1.0 label)
	  collect (gethash (svref row 0) string-index-table) into a-list
	  if (= 1.0 label)
	  collect (gethash (svref row 1) string-index-table) into b-list
	  finally (return (values (coerce a-list 'vector)
				  (coerce b-list 'vector)))))
    
    (loop 
	for i of-type fixnum below (length a-array)
	as j = (svref a-array i)
	as k = (svref b-array i)
	do (loop
	       while (/= (svref class-id-array j) j)
	       do (setf j (svref class-id-array j)))
	   (loop 
	       while
		 (/= (svref class-id-array k) k)
	       do (setf k (svref class-id-array k)))
	   (when (/= j k)
	     (setf (svref class-id-array j) k)))

    ;;compute class-id-array
    (loop
	for j of-type fixnum below n
	do (loop
	       while (/= (svref class-id-array j) (svref class-id-array (svref class-id-array j)))
	       do (setf (svref class-id-array j) (svref class-id-array (svref class-id-array j)))))

    ;;class-id-array->clustering-result
    (loop
	with class-id-table = (loop
				  with class-id-table = (make-hash-table)
				  for class-id across class-id-array
				  do (setf (gethash class-id class-id-table) 0)
				  finally (return class-id-table))
	for class-id of-type fixnum being the hash-keys in class-id-table
	collect (loop
    		    for i of-type fixnum below n
    		    as string = (svref string-array i)
    		    if (= class-id (svref class-id-array i))
    		    collect string) into clustering-result
    	finally (return clustering-result))))
