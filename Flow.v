
From Coq Require Import ZArith Lia Bool List String Program.Equality.
From Coq Require Import FunctionalExtensionality PropExtensionality.
From CDF Require Import Sequences Separation Seplog.

Local Open Scope string_scope.
Local Open Scope nat_scope.
Local Open Scope list_scope.

Section Flow.

Definition flow : Type := heap -> heap -> Prop.

Definition fexists {A: Type} (P: A -> flow) : flow :=
  fun h1 h2 => exists a: A, P a h1 h2.

(* h3 is the part of the heap that is taken away by req,
   h4 is what is left *)
Definition freq (P: precond) (k : flow) : flow :=
  fun h1 h2 => exists h3 h4,
    h1 = hunion h3 h4 /\ hdisjoint h3 h4 /\ P h3
    ->
    k h4 h2.

Definition fens (P: postcond) : flow :=
  fun h1 h2 => exists h3,
  exists r, (* TODO *)
    P r h3 /\ h2 = hunion h1 h3 /\ hdisjoint h1 h3.

Definition fempty : flow := fens (fun r h => True).

Definition fseq (f1 f2 : flow) : flow :=
  fun h1 h2 => exists h3, f1 h1 h3 /\ f2 h3 h2.
  (* fun h1 h2 => exists h3, f1 h1 h3 -> f2 h3 h2. *)

Infix ";;" := fseq (at level 80, right associativity).

(* TODO disjunction *)

(* TODO functions *)

(* Definition fn (name : string) : flow :=
  fun _ => True. *)

(* forward rules. says how to produce a flow from a program *)
Inductive forward : com -> flow -> Prop :=
  | fw_skip:
    forward SKIP fempty
  | fw_pure: forall n,
    forward (PURE n) (fens (fun res => pure (res = n)))
  | fw_get: forall l v, 
    forward (GET l)
      (freq (contains l v)
      (fens (fun r => (r = v) //\\ contains l v)))


  (* | fw_set: forall f l v, *)
    (* forward f (SET l v) f *)
  (* | fw_let: forall f e1 e2, *)
    (* forward f (LET e1 e2) f *)

  .

Inductive satisfies : heap -> flow -> heap -> Prop :=
  | m_req: forall h1 h2 p k,
    satisfies h1 (freq p k) h2
  | m_ens: forall h1 h2 q,
    satisfies h1 (fens q) h2

.

(* Example e1 : forall h1 h2, red (PURE 0, h1) (PURE 0, h2).
intros.
Qed. *)


(* Inductive a : flow -> com -> flow -> Prop := . *)

(* Inductive red: com * heap -> com * heap -> Prop := *)

(* red is a small step relation, soundness eventually needs to be proved for star red *)

(* Ltac inv H := inversion H; clear H; subst. *)

Definition terminated (c: com) : Prop :=  c = SKIP.

Definition terminates (c1: com) (h1 h2: heap) : Prop :=
  exists c2, star red (c1, h1) (c2, h2) /\ terminated c2.

(* Definition goeswrong (c1: com) (h1: heap) : Prop :=
  exists c2 h2, star red (c1, h1) (c2, h2) /\ error c2 h2. *)

(* Fixpoint error (c: com) (s: heap) : Prop :=
  match c with
  | ASSERT b => beval b s = false
  | (c1 ;; c2) => error c1 s
  | _ => False
  end. *)


Theorem soundness : forall f c1 h1 h2 h3,
  forward c1 f ->
  terminates c1 h1 h2 ->
  satisfies h1 f h3 ->
  h2 = h3.
Proof.
admit.
Admitted.

Theorem soundness0 : forall f c1 c2 h1 h2,
(* TODO doesn't say anything about stuff that doesn't reduce, like pure *)
  red (c1, h1) (c2, h2) ->
  forward c1 f ->
  f h1 h2.
Proof.
  intros f c1 c2 h1 h2 Hr Hf.
  induction Hf.
  - inv Hr.
  - inv Hr.
  -
  (* inversion Hr. *)
  (* assert (fh = fempty). *)
  inv Hr.

  (* assuming we start in state h2 *)
  (* the intermediate states in sequencing are also h2 *)
  (* unfold fseq. *)
  (* exists h2. *)
  (* intros hist. *)

  (* now partition the heap into h2 and emp,
  and assume there is h2[l:=v] *)
  unfold freq.
  exists (hsingle l v).
  exists (hfree l h2).
  intros [h3 [h4 Hd]].
  subst.
  (* h2 is now called h0, and h4 is empty *)

  (* add another empty piece of heap, h3 *)
  unfold fens.
  exists (hsingle l v).
  exists v.
  subst.
  split.
  split; reflexivity.
  split.
  + rewrite hunion_comm; auto.
  + rewrite hdisjoint_sym; auto.
Qed.
(* Admitted. *)

End Flow.
