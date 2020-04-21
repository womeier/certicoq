(* Syntactic properties of closure conversion. Part of the CertiCoq project.
 * Author: Zoe Paraskevopoulou, 2016
 *)

From CertiCoq Require Import L6.cps L6.size_cps L6.cps_util L6.set_util L6.hoisting L6.identifiers L6.ctx
     L6.Ensembles_util L6.List_util L6.functions L6.closure_conversion L6.eval L6.tactics.
Require Import compcert.lib.Coqlib.
Require Import Coq.ZArith.Znumtheory ArithRing Coq.Relations.Relations Coq.Arith.Wf_nat.
Require Import Coq.Lists.List Coq.MSets.MSets Coq.MSets.MSetRBT Coq.Numbers.BinNums
        Coq.NArith.BinNat Coq.PArith.BinPos Coq.Sets.Ensembles Omega.

Import ListNotations.

Open Scope ctx_scope.
Open Scope fun_scope.
Close Scope Z_scope.


(** * Syntactic Properties of the closure conversion relation *)

Section Closure_conversion_util.

  Variable clo_tag : ctor_tag.

  Lemma project_vars_length Scope Funs GFuns σ c genv Γ FVs S x y C Q :
    project_vars clo_tag Scope Funs GFuns σ c genv Γ FVs S x y C Q ->
    @List.length var x = @List.length var y.
  Proof.
    intros Hp; induction Hp; eauto. simpl; congruence.
  Qed.
    
  (* TODO : do this with autorewrites *)
  Ltac normalize_sets :=
    match goal with
      | [|- context[FromList []]] => rewrite FromList_nil
      | [|- context[FromList(_ :: _)]] => rewrite FromList_cons
      | [|- context[FromList(_ ++ _)]] => rewrite FromList_app
      | [|- context[FromList [_ ; _]]] => rewrite FromList_cons
      | [|- context[Union _ _ (Empty_set _)]] =>
        rewrite Union_Empty_set_neut_r
      | [|- context[Union _ (Empty_set _) _]] =>
        rewrite Union_Empty_set_neut_l
      | [|- context[Setminus _ (Empty_set _) _]] =>
        rewrite Setminus_Empty_set_abs_r
      | [|- context[Setminus _ _ (Empty_set _)]] =>
        rewrite Setminus_Empty_set_neut_r
      | [ H : context[FromList []] |- _] => rewrite FromList_nil in H
      | [ H : context[FromList(_ :: _)] |- _] => rewrite FromList_cons in H
      | [ H : context[FromList(_ ++ _)] |- _] => rewrite FromList_app in H
      | [ H : context[FromList [_ ; _]] |- _] => rewrite FromList_cons in H
      | [ H : context[Union _ _ (Empty_set _)] |- _ ] =>
        rewrite Union_Empty_set_neut_r in H
      | [ H : context[Union _ (Empty_set _) _] |- _] =>
        rewrite Union_Empty_set_neut_l in H
      | [ H : context[Setminus _ (Empty_set _) _] |- _] =>
        rewrite Setminus_Empty_set_abs_r in H
      | [ H : context[Setminus _ _ (Empty_set _)] |- _] =>
        rewrite Setminus_Empty_set_neut_r in H
    end.

  Lemma project_var_occurs_free_ctx_Included Scope Funs GFuns σ c genv Γ FVs S x y C Q F e:
    project_var clo_tag Scope Funs GFuns σ c genv Γ FVs S x y C Q ->
    (occurs_free e) \subset (F :|: [set y]) ->
    (Scope :|: (image σ ((Funs \\ Scope) :|: GFuns) :|: image genv (Funs \\ Scope)) :|: [set Γ]) \subset F ->
    (occurs_free (C |[ e ]|)) \subset F. 
  Proof with now eauto with Ensembles_DB functions_BD. 
    intros Hproj Hinc1 Hinc2. inv Hproj.
    - simpl. eapply Included_trans. eassumption. 
      apply Union_Included. now apply Included_refl.
      eapply Included_trans; [| eassumption ].
      eauto with Ensembles_DB.
    - simpl.
      rewrite occurs_free_Econstr, !FromList_cons, FromList_nil,
      Union_Empty_set_neut_r.
      eapply Union_Included.
      + rewrite image_Union in Hinc2.
        eapply Included_trans; [| now apply Hinc2 ].
        eapply Union_Included.
        eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. do 2 eapply Included_Union_preserv_l.
        eapply Singleton_Included. eapply In_image. constructor; eauto.

        eapply Included_Union_preserv_l. do 2 eapply Included_Union_preserv_r. 
        eapply Singleton_Included. eapply In_image. constructor; eauto.
      + eauto with Ensembles_DB.
    - simpl. 
      repeat normalize_occurs_free.
      rewrite FromList_cons, FromList_nil, Union_Empty_set_neut_l.
      rewrite FromList_singleton. rewrite !Setminus_Union_distr.
      rewrite Setminus_Same_set_Empty_set, Union_Empty_set_neut_r.
      eapply Union_Included.
      + rewrite image_Union in Hinc2.
        eapply Included_trans; [| now apply Hinc2 ].
        eauto 10 with Ensembles_DB functions_BD.        
      + eauto with Ensembles_DB.
    - simpl. rewrite occurs_free_Eproj.
      eapply Union_Included.
      + eapply Included_trans; [| now apply Hinc2 ]...
      + eauto with Ensembles_DB.
  Qed.

  
  Lemma project_vars_occurs_free_ctx_Included Scope Funs GFuns σ c Γ genv
    FVs S xs xs' C S' F e:
    project_vars clo_tag Scope Funs GFuns σ c genv Γ FVs S xs xs' C S' ->
    (occurs_free e) \subset (F :|: (FromList xs')) ->
    (Scope :|: (image σ (Funs \\ Scope :|: GFuns) :|: image genv (Funs \\ Scope)) :|: [set  Γ]) \subset F ->
    occurs_free (C |[ e ]|) \subset F. 
  Proof. 
    intros Hproj. revert F.
    induction Hproj; intros F Hinc1 Hinc2; repeat normalize_sets.
    - eassumption.
    - rewrite <- app_ctx_f_fuse.
      eapply project_var_occurs_free_ctx_Included; [ eassumption | | eassumption ].
      eapply IHHproj. rewrite <- Union_assoc. eassumption.
      eapply Included_trans. eassumption. now apply Included_Union_l.
  Qed.

  Lemma project_var_occurs_free_ctx_alt_Included Scope Funs GFuns σ c genv Γ FVs S x y C Q F e:
    project_var clo_tag Scope Funs GFuns σ c genv Γ FVs S x y C Q ->
    (occurs_free e) \subset (F :|: [set y]) ->
    (Scope :|: ((image σ ([set x] :&: (Funs \\ Scope :|: GFuns)) :|: image genv (Funs \\ Scope))) :|: [set Γ]) \subset F ->
    (occurs_free (C |[ e ]|)) \subset F. 
  Proof with now eauto with Ensembles_DB functions_BD. 
    intros Hproj Hinc1 Hinc2. inv Hproj.
    - simpl. eapply Included_trans. eassumption. 
      apply Union_Included. now apply Included_refl.
      eapply Included_trans; [| eassumption ].
      eauto with Ensembles_DB.
    - simpl.
      rewrite occurs_free_Econstr, !FromList_cons, FromList_nil,
      Union_Empty_set_neut_r. 
      eapply Union_Included.
      + eapply Included_trans; [| now apply Hinc2 ].
        eapply Union_Included; sets. eapply Singleton_Included. left. right. left.
        eapply In_image. constructor; eauto. left; constructor; eauto.
        eapply Singleton_Included. left. right. right. 
        eapply In_image. constructor; eauto.        
      + eauto with Ensembles_DB.
    - simpl. 
      repeat normalize_occurs_free.
      rewrite FromList_cons, FromList_nil, Union_Empty_set_neut_l.
      rewrite FromList_singleton. rewrite !Setminus_Union_distr.
      rewrite Setminus_Same_set_Empty_set, Union_Empty_set_neut_r.
      eapply Union_Included.
      + eapply Included_trans; [| now apply Hinc2 ].
        eapply Setminus_Included_Included_Union.
        eapply Singleton_Included. left. left. right. left.
        eapply In_image. econstructor; eauto.
      + eauto with Ensembles_DB.
    - simpl. rewrite occurs_free_Eproj.
      eapply Union_Included.
      + eapply Included_trans; [| now apply Hinc2 ]...
      + eauto with Ensembles_DB.
  Qed.

  
  Lemma project_vars_occurs_free_ctx_alt_Included Scope Funs GFuns σ c genv Γ
        FVs S xs xs' C S' F e:
    project_vars clo_tag Scope Funs GFuns σ c genv Γ FVs S xs xs' C S' ->
    Included _ (occurs_free e) (Union _ F (FromList xs')) ->
    Included _ (Scope :|: (Union _ (image σ (FromList xs :&: (Funs \\ Scope :|: GFuns)) :|: image genv (Funs \\ Scope)) (Singleton _ Γ))) F ->
    Included _ (occurs_free (C |[ e ]|)) F. 
  Proof. 
    intros Hproj. revert F.
    induction Hproj; intros F Hinc1 Hinc2; repeat normalize_sets.
    - eassumption.
    - rewrite <- app_ctx_f_fuse.
      eapply project_var_occurs_free_ctx_alt_Included; [ eassumption | | ].
      eapply IHHproj. rewrite <- Union_assoc. eassumption.
      eapply Included_trans. eapply Included_trans; [| eapply Hinc2 ]; sets.
      eapply Included_Union_compat; sets.
      eapply Included_Union_compat; sets.
      eapply Included_Union_compat; sets. eapply image_monotonic.
      eapply Included_Intersection_compat; sets. sets.
      eapply Included_trans; [| eassumption ].
      rewrite !Union_assoc.  eapply Included_Union_compat; sets.
      eapply Included_Union_compat; sets.
      eapply Included_Union_compat; sets. eapply image_monotonic.
      eapply Included_Intersection_compat; sets.
  Qed.

  
  Lemma project_var_In_Union Scope Funs GFuns σ c genv Γ FVs S x x' C S' :
    project_var clo_tag Scope Funs GFuns σ c genv Γ FVs S x x' C S' ->
    x \in (Scope :|: Funs :|: GFuns :|: FromList FVs).
  Proof.
    intros Hvar. inv Hvar; eauto.
    right. eapply nthN_In. eassumption.
  Qed.

  Lemma project_vars_In_Union Scope Funs GFuns σ c genv Γ FVs S xs xs' C S' :
    project_vars clo_tag Scope Funs GFuns σ c genv Γ FVs S xs xs' C S' ->
    (FromList xs) \subset (Scope :|: Funs :|: GFuns :|: FromList FVs).
  Proof.
    intros Hvar. induction Hvar; eauto.
    - rewrite FromList_nil. now apply Included_Empty_set.
    - rewrite FromList_cons.
      eapply Union_Included; [| eassumption ].
      eapply Singleton_Included. eapply project_var_In_Union.
      eassumption.
  Qed.


    (** * Lemmas about [add_global_funs] *)
  
  Lemma add_global_funs_included G F {_ : Decidable F} V G' :
    add_global_funs G F V G' ->
    G \subset G' :|: F.
  Proof. 
    intros Hin. inv Hin; sets.
  Qed.
  
  Lemma add_global_funs_included_r G F V G' :
    add_global_funs G F V G' ->
    G' \subset G :|: F.
  Proof. 
    intros Hin. inv Hin; sets.
  Qed.

  Definition is_gfuns (GFuns : Ensemble var) names (FVs : list var) GFuns' :=
    (FVs = [] /\ GFuns' \subset GFuns :|: names) \/
    (FVs <> [] /\ GFuns' \subset GFuns \\ names).

  Lemma add_global_funs_is_gfuns (GFuns : Ensemble var) names (FVs : list var) GFuns':
    add_global_funs GFuns names (FromList FVs) GFuns' ->
    is_gfuns GFuns names FVs GFuns'.
  Proof.
    intros Hin; destruct FVs; inv Hin; unfold is_gfuns; sets.
    - exfalso. eapply not_In_Empty_set. eapply H.
      now left.
    - right. split; sets. congruence.
  Qed.

  Lemma is_gfuns_setminus (GFuns : Ensemble var) names (FVs : list var) GFuns' x:
   is_gfuns GFuns (x |: names) FVs GFuns' ->
   is_gfuns GFuns names FVs (GFuns' \\ [set x]).
  Proof.
    intros [[H1 H2] | [H1 H2]]; subst; unfold is_gfuns in *.
    left; split; eauto.
    eapply Setminus_Included_Included_Union. eapply Included_trans. eassumption. sets.
    right; split; eauto.
    eapply Setminus_Included_Included_Union. eapply Included_trans. eassumption. sets.
  Qed.

  Lemma is_gfuns_included_r G F {_ : Decidable F} V G' :
    is_gfuns G F V G' ->
    G' \subset G :|: F.
  Proof. 
    intros Hin. destruct Hin as [[? ?] | [? ?]]; subst; sets.
    eapply Included_trans. eassumption. sets.
  Qed.

  Lemma add_global_funs_is_gfuns_included (GFuns : Ensemble var) names (FVs : list var) GFuns' GFuns'' :
    add_global_funs GFuns names (FromList FVs) GFuns' ->
    is_gfuns GFuns names FVs GFuns'' ->
    GFuns'' \subset GFuns'.
  Proof.
    intros Hadd Hin; destruct Hin as [[? ?] | [? ?]]; inv Hadd; unfold is_gfuns; sets.
    - eapply Included_trans. eassumption. sets.
    - rewrite FromList_nil in H1. exfalso; eapply H1; reflexivity.
    - eapply Included_trans. eassumption. sets.
  Qed.

  (** * Lemmas about [make_closures] *)

  Lemma make_closures_free_set_Included B S Γ C σ  S' :
    make_closures clo_tag B S Γ C σ S' ->
    S' \subset S.
  Proof. 
    intros Hmc. induction Hmc.
    - now apply Included_refl.
    - eapply Included_trans. eassumption.
      now apply Setminus_Included.
  Qed.

  Lemma make_closures_image_Included B S Γ C σ S' :
    make_closures clo_tag B S Γ C σ S' ->
    Included _ (image σ (name_in_fundefs B)) (S \\ S').
  Proof. 
    intros Hmc. induction Hmc.
    - rewrite image_Empty_set. apply Included_Empty_set.
    - simpl. subst. 
      rewrite image_Union, image_Singleton.
      apply Union_Included. apply Singleton_Included.
      constructor; eauto. eapply make_closures_free_set_Included in Hmc.
      now intros Hc; eapply Hmc; eauto. 
      eapply Included_trans. eassumption.
      now eauto with Ensembles_DB.
  Qed.

  Lemma make_closures_image_eq B S Γ C σ S' :
    unique_functions B ->
    make_closures clo_tag B S Γ C σ S' ->
    (image σ (name_in_fundefs B)) <--> (S \\ S').
  Proof. 
    intros Hun Hmc. induction Hmc.
    - rewrite image_Empty_set, Setminus_Same_set_Empty_set. reflexivity.
    - simpl. subst. 
      rewrite image_Union, image_Singleton.
      inv Hun. rewrite IHHmc; [| eassumption ].
      rewrite Setminus_Union, (Union_commut [set _] S'), <- Setminus_Union. 
      rewrite Union_Setminus_Included, Union_Same_set. reflexivity.                                                         
      eapply Singleton_Included. constructor. eassumption.
      eapply make_closures_free_set_Included in Hmc.
      now intros Hc; eapply Hmc; eauto.
      tci. reflexivity.
  Qed.

  Lemma make_closures_image_set B S Γ C σ S' P  :
    make_closures clo_tag B S Γ C σ S' ->
    image σ P \subset image σ (P \\ name_in_fundefs B) :|: (S \\ S').
  Proof.
    intros Hmc. revert P. induction Hmc; intros P.
    - simpl. rewrite Setminus_Empty_set_neut_r, Setminus_Same_set_Empty_set, Union_Empty_set_neut_r.
      reflexivity.
    - simpl. subst.
      eapply Included_trans. eapply image_monotonic.
      eapply Included_Union_Setminus with (s2 := [set f]); tci.
      rewrite image_Union, image_Singleton.
      eapply Union_Included.
      + eapply Included_trans. eapply IHHmc.
        eapply Union_Included. 
        eapply Included_Union_preserv_l. eapply image_monotonic.
        now sets.
        now sets.
      + eapply Singleton_Included. right. constructor; eauto.
        eapply make_closures_free_set_Included in Hmc.
        now intros Hc; eapply Hmc; eauto.
  Qed.

  Lemma make_closures_image_Disjoint B S Γ C σ  S' :
    make_closures clo_tag B S Γ C σ S' ->
    Disjoint _ (image σ (name_in_fundefs B)) S'.
  Proof.
    intros Hc. constructor. intros x H1. inv H1.
    eapply make_closures_image_Included in H; [| eassumption ].
    now inv H.
  Qed.

  Lemma make_closures_injective GFuns B S Γ C σ S' :
    Disjoint _ S (name_in_fundefs B) ->
    Disjoint _ S (image σ GFuns) ->
    injective_subdomain GFuns σ ->
    make_closures clo_tag B S Γ C σ S' ->
    injective_subdomain (name_in_fundefs B :|: GFuns) σ.
  Proof.
    revert GFuns S Γ C σ S'; induction B; intros GFuns S Γ C σ S' Hd Hd' Hinj Hmc.
    - simpl. inv Hmc.
      rewrite <- Union_assoc. eapply injective_subdomain_Union.
      + eapply injective_subdomain_Singleton.
      + eapply IHB; [| | | eassumption ].
        now eapply Disjoint_Included; [| | eapply Hd ]; sets.
        sets.
        eassumption.
      + rewrite image_Singleton, image_Union.
        eapply Union_Disjoint_r.
        eapply Disjoint_Included_r.
        eapply make_closures_image_Included. eassumption. now sets.
        eapply Disjoint_Included_l; [| eassumption ].
        eapply Singleton_Included. eassumption.
    - simpl. rewrite Union_Empty_set_neut_l. eassumption.
  Qed.

  Lemma make_closures_occurs_free_ctx_Included B S Γ C f S' F e:
    unique_functions B ->
    make_closures clo_tag B S Γ C f S'  ->
    Included _ (occurs_free e) (Union _ F (name_in_fundefs B)) ->
    (S \\ S') :|: [set Γ] \subset F ->
    Included _ (occurs_free (C |[ e ]|)) F. 
  Proof with now eauto with Ensembles_DB functions_BD. 
    intros Hun Hmc. revert F.
    induction Hmc; intros F Hinc1 Hinc2;
    simpl in *; repeat normalize_sets; (repeat normalize_occurs_free).
    - eassumption.
    - repeat normalize_sets.
      apply Union_Included. apply Union_Included.
      eapply Included_trans; [| eassumption ].
      eapply Singleton_Included. constructor; eauto. constructor; eauto.
      eapply make_closures_free_set_Included in Hmc. intros Hc. eapply Hmc.
      eassumption. now constructor.
      now eauto with Ensembles_DB. 
      eapply Setminus_Included_Included_Union.
      inv Hun. eapply IHHmc.
      eassumption. 
      eapply Included_trans; [ eapply Hinc1 |]...
      eapply Included_trans; [| eapply Included_Union_l ].
      eapply Included_trans; [| eassumption ]...
  Qed.

  (** * Lemmas about [make_closure_names] *)

  Lemma make_closure_names_free_set_Included B S σ  S' :
    make_closure_names B S σ S' ->
    S' \subset S.
  Proof. 
    intros Hmc. induction Hmc.
    - now apply Included_refl.
    - eapply Included_trans. eassumption.
      now apply Setminus_Included.
  Qed.


  Lemma make_closure_names_image_eq B S σ S' :
    unique_functions B ->
    make_closure_names B S σ S' ->
    (image σ (name_in_fundefs B)) <--> (S \\ S').
  Proof. 
    intros Hun Hmc. induction Hmc.
    - rewrite image_Empty_set, Setminus_Same_set_Empty_set. reflexivity.
    - simpl. subst. 
      rewrite image_Union, image_Singleton.
      inv Hun. rewrite IHHmc; [| eassumption ]. 
      rewrite Setminus_Union, (Union_commut [set _] S'), <- Setminus_Union. 
      rewrite Union_Setminus_Included, Union_Same_set. reflexivity.                                                         apply Singleton_Included. constructor. eassumption.
      eapply make_closure_names_free_set_Included in Hmc.
      now intros Hc; eapply Hmc; eauto.
      tci. reflexivity.
  Qed.

  Lemma make_closure_names_image_Included B S σ S' :
    make_closure_names B S σ S' ->
    Included _ (image σ (name_in_fundefs B)) (S \\ S').
  Proof. 
    intros Hmc. induction Hmc.
    - rewrite image_Empty_set. apply Included_Empty_set.
    - simpl. subst. 
      rewrite image_Union, image_Singleton.
      apply Union_Included. apply Singleton_Included.
      constructor; eauto. eapply make_closure_names_free_set_Included in Hmc.
      now intros Hc; eapply Hmc; eauto. 
      eapply Included_trans. eassumption.
      now eauto with Ensembles_DB.
  Qed.

  Lemma make_closure_names_injective GFuns B S σ S' :
    Disjoint _ S (name_in_fundefs B) ->
    Disjoint _ S (image σ GFuns) ->
    injective_subdomain GFuns σ ->
    make_closure_names B S σ S' ->
    injective_subdomain (name_in_fundefs B :|: GFuns) σ.
  Proof.
    revert GFuns S σ S'; induction B; intros GFuns S σ S' Hd Hd' Hinj Hmc.
    - simpl. inv Hmc.
      rewrite <- Union_assoc. eapply injective_subdomain_Union.
      + eapply injective_subdomain_Singleton.
      + eapply IHB; [| | | eassumption ].
        now eapply Disjoint_Included; [| | eapply Hd ]; sets.
        sets.
        eassumption.
      + rewrite image_Singleton, image_Union.
        eapply Union_Disjoint_r. eapply Disjoint_Included_r.
        eapply make_closure_names_image_Included. eassumption. now sets.
        eapply Disjoint_Included_l; [| eassumption ].
        eapply Singleton_Included. eassumption.
    - simpl. rewrite Union_Empty_set_neut_l. eassumption.
  Qed.


  (** * Lemmas about [extend_fundefs'] *)
  
  Lemma extend_fundefs'_get_s f B x z :
    z \in name_in_fundefs B ->
          extend_fundefs' f B x z = x.
  Proof.
    intros Heq. unfold extend_fundefs'.
    destruct (Dec z); eauto.
    exfalso; eauto.
  Qed.

  Lemma extend_fundefs'_get_o f B x z :
    ~ z \in name_in_fundefs B ->
            extend_fundefs' f B x z = f z.
  Proof.
    intros Heq. unfold extend_fundefs'.
    destruct (Dec z); eauto.
    exfalso; eauto.
  Qed.

  Lemma extend_fundefs'_image f B x :
    image (extend_fundefs' f B x) (name_in_fundefs B) \subset [set x].  
  Proof.
    intros y Hin.
    destruct Hin as [z [Hin' Heq]]. 
    rewrite extend_fundefs'_get_s in Heq. subst; eauto.
    eassumption.
  Qed.

  Lemma extend_fundefs'_image_Included f B x S :
    image (extend_fundefs' f B x) S \subset x |: image f S.  
  Proof.
    intros y Hin.
    destruct Hin as [z [Hin' Heq]]. 
    unfold extend_fundefs' in *.
    destruct (Dec z); subst; eauto.
    right. eexists; split; eauto.
  Qed.

  Lemma extend_fundefs'_image_Included' f B x S :
    image (extend_fundefs' f B x) S \subset x |: image f (S \\ name_in_fundefs B).  
  Proof.
    intros y Hin.
    destruct Hin as [z [Hin' Heq]]. 
    unfold extend_fundefs' in *.
    destruct (Dec z); subst; eauto.
    right. eexists; split; eauto. constructor; eauto. 
  Qed.

  Lemma extend_fundefs'_same_funs f B B' x :
    name_in_fundefs B <--> name_in_fundefs B' ->
    f_eq (extend_fundefs' f B x) (extend_fundefs' f B' x).
  Proof.
    intros Heq y. unfold extend_fundefs'. destruct Heq.
    destruct (@Dec _ (name_in_fundefs B) _ y);
      destruct (@Dec _ (name_in_fundefs B') _ y); eauto.
    eapply H in n. now exfalso; eauto.
    eapply H0 in n0. now exfalso; eauto.
  Qed.

  
  Lemma project_var_free_funs_in_exp Scope Funs GFuns σ c genv Γ FVs S x x' C S' B e:
    project_var clo_tag Scope Funs GFuns σ c genv Γ FVs S x x' C S' ->
    (funs_in_exp B (C |[ e ]|) <-> funs_in_exp B e).
  Proof. 
    intros Hvar; inv Hvar; [ split; now eauto | |  |];
      try (split; intros Hf; [ now inv Hf | now constructor ]).
    - split; intros Hf.
      inv Hf. inv H6. eassumption.
      constructor. now constructor. 
  Qed.

  Lemma project_vars_free_funs_in_exp Scope Funs GFuns σ c genv Γ FVs S xs xs' C S' B e:
    project_vars clo_tag Scope Funs GFuns σ c genv Γ FVs S xs xs' C S' ->
    (funs_in_exp B (C |[ e ]|) <-> funs_in_exp B e).
  Proof. 
    intros Hvar; induction Hvar; [ now eauto |].
    rewrite <- app_ctx_f_fuse, project_var_free_funs_in_exp; eassumption.
  Qed.

  Lemma make_closures_funs_in_exp B S Γ C σ S' B' e:
    make_closures clo_tag B S Γ C σ S'  ->
    (funs_in_exp B' (C |[ e ]|) <-> funs_in_exp B' e).
  Proof.
    intros Hmc; induction Hmc;
    [ split; now eauto | ].
    rewrite <- IHHmc. split; eauto; intros Hf; [ now inv Hf | now constructor ].
  Qed.

  Lemma closure_conversion_fundefs_Same_set_image σ c Funs GFuns FVs B1 B2  :
    Closure_conversion_fundefs clo_tag Funs GFuns σ c FVs B1 B2 ->
    Same_set _ (image σ (name_in_fundefs B1)) (name_in_fundefs B2).
  Proof. 
    intros Hcc. induction Hcc.  
    - simpl. rewrite image_Union, image_Singleton, IHHcc.
      apply Same_set_refl.
    - simpl. rewrite image_Empty_set. apply Same_set_refl.
  Qed.


  Lemma Setminus_eq_Included A (s1 s2 s3 : Ensemble A) {_ : Decidable s2} :
    s1 \\ s2 <--> s3 ->
    s1 \subset s2 :|: s3.
  Proof.
    intros H x Hin. rewrite <- H.
    destruct X. destruct (Dec x); eauto.
    right; constructor; eauto.
  Qed. 

  Lemma add_global_funs_Dec G N F G' :
    add_global_funs G N F G' ->
    Decidable G ->
    Decidable N ->    
    Decidable G'.
  Proof.
    intros Ha H1 H2. inv Ha; tci.
  Qed. 
    
  Lemma Closure_conversion_occurs_free_pre_Included :
    (forall e Scope Funs GFuns {_ : Decidable GFuns} σ c genv Γ FVs e' C 
       (Hcc : Closure_conversion clo_tag Scope Funs GFuns σ c genv Γ FVs e e' C),
        (occurs_free e) \subset (Scope :|: Funs :|: GFuns :|: FromList FVs)).
  Proof with now eauto with Ensembles_DB functions_BD.
    induction e using exp_ind'; intros; inv Hcc; normalize_occurs_free.
    - eapply Union_Included. eapply project_vars_In_Union. eassumption.
      eapply IHe in H16. eapply Setminus_Included_Included_Union.
      eapply Included_trans. eassumption. repeat (eapply Union_Included; sets).
      tci. 
    - eapply Singleton_Included. eapply project_var_In_Union. eassumption.
    - eapply Union_Included. 
      eapply Singleton_Included. eapply project_var_In_Union. eassumption.
      inv H14. destruct H3 as [Hfeq [C1 [e1 [Hceq Hcc]]]].
      eapply Union_Included.
      eapply IHe; eassumption.
      eapply IHe0; eauto. econstructor; eauto.
    - eapply Union_Included. eapply Singleton_Included. eapply project_var_In_Union. eassumption.
      eapply IHe in H17. eapply Setminus_Included_Included_Union.
      eapply Included_trans. eassumption. repeat (eapply Union_Included; sets). tci.
    - eapply Union_Included. rewrite <- FromList_cons. eapply project_vars_In_Union. eassumption.
      eapply IHe in H20. eapply Setminus_Included_Included_Union.
      eapply Included_trans. eassumption. repeat (eapply Union_Included; sets). tci.
    - eapply Union_Included.
      eapply Included_trans. eapply Setminus_eq_Included; [| eassumption ]. tci.
      eapply Union_Included. sets.
      eapply project_vars_In_Union. eassumption.
      eapply IHe in H21; tci. eapply Setminus_Included_Included_Union.
      eapply Included_trans. eassumption.
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      now eapply Union_Included; sets.
      eapply Included_trans. eapply add_global_funs_included_r. eassumption. sets.
      eapply add_global_funs_Dec. eassumption. tci. tci.
    - eapply Included_trans; [| eapply project_vars_In_Union; eauto ].
      normalize_sets...
    - eapply Union_Included. eapply project_vars_In_Union. eassumption.
      eapply IHe in H16. eapply Setminus_Included_Included_Union.
      eapply Included_trans. eassumption. repeat (eapply Union_Included; sets).
      tci.
    - eapply Singleton_Included. eapply project_var_In_Union. eassumption.
  Qed.  
  
  Lemma Closure_conversion_occurs_free_Included_mut :
    (forall e Scope Funs GFuns σ c genv Γ FVs e' C 
       (Hcc : Closure_conversion clo_tag Scope Funs GFuns σ c genv Γ FVs e e' C)
       (Hun: fundefs_names_unique e),
        occurs_free (C |[ e' ]|) \subset (Scope :|: (image σ (Funs \\ Scope :|: GFuns) :|: image genv (Funs \\ Scope)) :|: [set Γ])) /\
    (forall B Bg GFuns σ c FVs B'
       (Hcc: Closure_conversion_fundefs clo_tag Bg GFuns σ c FVs B B')
       (Hun: fundefs_names_unique_fundefs B),
       occurs_free_fundefs B' \subset (image σ (name_in_fundefs Bg :|: GFuns) \\ (name_in_fundefs B'))).
  Proof with now eauto with Ensembles_DB functions_BD.
    exp_defs_induction IHe IHl IHB; intros; inv Hcc.
    - eapply project_vars_occurs_free_ctx_Included;
      [ eassumption | | now apply Included_refl ].
      rewrite occurs_free_Econstr.
      apply Union_Included. now eauto with Ensembles_DB.
      apply Setminus_Included_Included_Union.
      eapply Included_trans. eapply IHe. eassumption.
      intros f Hunf. eapply Hun. now constructor.
      rewrite Union_commut with (s2 := Singleton var v), !Union_assoc.      
      eapply Union_Included; sets.
      eapply Union_Included; eauto 10 with Ensembles_DB functions_BD.      
    - eapply project_var_occurs_free_ctx_Included;
        [ eassumption | | now apply Included_refl ]. inv H13.
      rewrite occurs_free_Ecase_nil. now apply Included_Union_r.
    - inv H13. destruct y as [c' e'].
      inv H2. simpl in H; subst. destruct H0 as [C' [e'' [Heq Hcce]]]. simpl in Heq; subst. 
      eapply Included_trans. now eapply occurs_free_Ecase_ctx_app.
      apply Union_Included. 
      + eapply project_var_occurs_free_ctx_Included;
        [ eassumption | | now apply Included_refl ].
        eapply Included_trans. eapply IHe. eassumption.
        intros f Hunf. eapply Hun. econstructor. eassumption. now constructor.
        now apply Included_Union_l.
      + eapply IHl. econstructor; eauto.
        intros f Hunf. eapply Hun. inv Hunf. econstructor 2. eassumption.
        econstructor 2. eassumption. 
    - eapply project_var_occurs_free_ctx_Included;
      [ eassumption | | now apply Included_refl ].
      rewrite occurs_free_Eproj.
      rewrite Union_commut.
      apply Included_Union_compat; [| now apply Included_refl ].
      apply Setminus_Included_Included_Union.
      eapply Included_trans. eapply IHe. eassumption.
      intros f Hunf. eapply Hun. now constructor.      
      eapply Union_Included; [| sets ].
      eapply Union_Included; [| sets ].
      eapply Union_Included; sets.
      eauto 10 with Ensembles_DB functions_BD.
    - eapply project_vars_occurs_free_ctx_Included; [ eassumption | | now apply Included_refl ].
      repeat normalize_occurs_free. repeat normalize_sets. 
      eapply Union_Included.
      now eauto with Ensembles_DB.
      eapply Setminus_Included_Included_Union.
      eapply Union_Included.
      now eauto with Ensembles_DB.
      eapply Setminus_Included_Included_Union.
      eapply Union_Included.      
      eapply Union_Included; now eauto with Ensembles_DB.
      eapply Setminus_Included_Included_Union.
      eapply Included_trans. eapply IHe. eassumption.
      intros h Hunf. eapply Hun. now constructor.
      eapply Union_Included; sets.
      eapply Union_Included; eauto 10 with Ensembles_DB functions_BD.
      eapply Union_Included; sets.
      do 5 eapply Included_Union_preserv_l.  eapply Included_Union_preserv_r. eapply Included_Union_preserv_l. sets.
      do 5 eapply Included_Union_preserv_l.  do 2 eapply Included_Union_preserv_r. sets.
    - rewrite <- app_ctx_f_fuse.
      eapply project_vars_occurs_free_ctx_Included;
        [ eassumption | | now apply Included_refl ].
      simpl. rewrite occurs_free_Econstr.
      apply Union_Included. now apply Included_Union_r.
      rewrite occurs_free_Efun. apply Setminus_Included_Included_Union.
      eapply Union_Included.  
      + eapply Included_trans. eapply IHB. eassumption.
        intros f Hunf. eapply Hun. now inv Hunf; eauto.
        eapply Setminus_Included_Included_Union.
        rewrite image_Union. rewrite closure_conversion_fundefs_Same_set_image; [| eassumption ].
        eapply Union_Included; sets.
        eapply Included_trans. eapply image_monotonic. eapply add_global_funs_included_r; eauto.
        rewrite !image_Union. rewrite closure_conversion_fundefs_Same_set_image; [| eassumption ].
        eauto 20 with Ensembles_DB. 
      + eapply Setminus_Included_Included_Union.
        eapply Included_trans. eapply IHe. eassumption.
        intros f Hunf. eapply Hun. now constructor.
        eapply Union_Included; sets.
        eapply Union_Included. xsets.
        eapply Union_Included; sets.
        * eapply Included_trans. eapply image_monotonic. eapply Included_Union_compat; [| reflexivity ].
          eapply Setminus_Setminus_Included. tci.
          rewrite Setminus_Union_distr.
          rewrite <- !Union_assoc.
          rewrite (Union_Same_set (name_in_fundefs _ \\ Scope)); sets.
          rewrite !image_Union.
          eapply Union_Included; eauto 10 with Ensembles_DB.
          eapply Union_Included; eauto 10 with Ensembles_DB.
          rewrite closure_conversion_fundefs_Same_set_image; [| eassumption ]. xsets.
          eapply Included_trans. eapply image_monotonic. eapply add_global_funs_included_r; eauto.
          rewrite !image_Union. rewrite closure_conversion_fundefs_Same_set_image; [| eassumption ].
          eauto 20 with Ensembles_DB.
        * eapply Included_trans. eapply extend_fundefs'_image_Included'.
          eapply Union_Included; sets.
          rewrite !Setminus_Union_distr. rewrite Setminus_Included_Empty_set; sets.
          rewrite Union_Empty_set_neut_l.
          eapply Included_trans. eapply image_monotonic. eapply Included_Setminus_compat; [| reflexivity ].
          eapply Setminus_Setminus_Included. tci.
          rewrite Setminus_Union_distr. rewrite Setminus_Same_set_Empty_set, Union_Empty_set_neut_r.
          xsets.
    - eapply project_vars_occurs_free_ctx_Included;
      [ eassumption | | now apply Included_refl ].
      repeat normalize_occurs_free. repeat normalize_sets.
      apply Union_Included. eauto with Ensembles_DB.
      apply Setminus_Included_Included_Union.
      apply Union_Included. eauto with Ensembles_DB.
      apply Setminus_Included_Included_Union.
      eauto 7 with Ensembles_DB.
    - eapply project_vars_occurs_free_ctx_Included;
      [ eassumption | | now apply Included_refl ].
      rewrite occurs_free_Eprim.
      apply Union_Included; [ now eauto with Ensembles_DB |]. 
      apply Setminus_Included_Included_Union.
      eapply Included_trans. eapply IHe. eassumption.
      intros f Hunf. eapply Hun. now constructor.      
      eapply Union_Included; [| sets ].
      eapply Union_Included; [| sets ].
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      eauto 10 with Ensembles_DB functions_BD.
      eauto 10 with Ensembles_DB functions_BD.
    - eapply project_var_occurs_free_ctx_Included; eauto.
      normalize_occurs_free... reflexivity. 
    - rewrite occurs_free_fundefs_Fcons.
      apply Union_Included.
      + apply Setminus_Included_Included_Union.
        eapply Included_trans. eapply IHe. eassumption.
        intros f Hunf. eapply Hun. left. now eauto.
        rewrite FromList_cons. simpl.
        eapply Union_Included; sets.
        eapply Union_Included; sets.
        eapply Union_Included; sets.
        * rewrite <- (Union_Included_Union_Setminus _ _ (_ |: _)); tci; sets. 
        * eapply Included_trans.
          eapply Included_trans. eapply image_monotonic. eapply Setminus_Included.
          eapply extend_fundefs'_image. sets.          
      + apply Setminus_Included_Included_Union.
        eapply Included_trans. eapply IHB. eassumption.
        intros f Hunf. inv Hunf; eauto.
        specialize (Hun (Fcons v t l e f5) (or_intror eq_refl)).
        now inv Hun; eauto.
        simpl. eapply Setminus_Included_Included_Union.
        rewrite <- Union_assoc, <- Union_Included_Union_Setminus;
          eauto with Ensembles_DB typeclass_instances.
    - rewrite occurs_free_fundefs_Fnil. now apply Included_Empty_set.
  Qed.

  (* TODO move *)
  Lemma Intersection_Union_Disjoint (A : Type) (S1 S2 S3 : Ensemble A) :
    Disjoint A S2 S3 -> (S1 :|: S2) :&: S3 <--> S1 :&: S3.
  Proof.
    intros Hd. split; eauto; intros x Hin; inv Hin; eauto.
    inv H; eauto. exfalso; eauto. eapply Hd; constructor; eauto.
  Qed.

  
  Lemma Closure_conversion_occurs_free_Included_alt_mut :
    (forall e Scope Funs GFuns σ c genv Γ FVs e' C 
       (Hcc : Closure_conversion clo_tag Scope Funs GFuns σ c genv Γ FVs e e' C)
       (Hun: fundefs_names_unique e),
        occurs_free (C |[ e' ]|) \subset
        Scope :|: (image σ (occurs_free e :&: (Funs \\ Scope :|: GFuns)) :|: image genv (Funs \\ Scope)) :|: [set Γ]) /\
    (forall B Bg GFuns σ c FVs B'
       (Hcc: Closure_conversion_fundefs clo_tag Bg GFuns σ c FVs B B')
       (Hun: fundefs_names_unique_fundefs B),
        occurs_free_fundefs B' \subset image σ (occurs_free_fundefs B :&: (name_in_fundefs Bg :|: GFuns))).
  Proof with now eauto with Ensembles_DB functions_BD.
    exp_defs_induction IHe IHl IHB; intros; inv Hcc.
    - eapply project_vars_occurs_free_ctx_alt_Included; [ eassumption | | sets ].
      repeat normalize_occurs_free.
      apply Union_Included. now eauto with Ensembles_DB. eapply Setminus_Included_Included_Union.
      eapply Included_trans. eapply IHe. eassumption. intros f Hfin. eapply Hun. now constructor.  
      eapply Union_Included; [| sets ].
      eapply Union_Included; [| sets ].
      now eapply Union_Included; sets.
      eapply Union_Included; xsets.
      
      do 3 eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
      eapply image_monotonic.
      rewrite <- Intersection_Setmius_Disjoint with (S2 := [set v]). eapply Included_Intersection_compat; sets.
      sets.

      eapply Union_Included; sets.
      eapply Union_Included; sets.
      normalize_occurs_free.  eapply Union_Included; sets. 
      eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
      eapply image_monotonic. eapply Included_Intersection_compat; sets.
    - eapply project_var_occurs_free_ctx_alt_Included; [ eassumption | | sets ]. inv H13.
      repeat normalize_occurs_free. sets.
      normalize_occurs_free... 
    - inv H13. destruct y as [c' e'].
      inv H2. simpl in H; subst. destruct H0 as [C' [e'' [Heq Hcce]]]. simpl in Heq; subst. 
      eapply Included_trans. now eapply occurs_free_Ecase_ctx_app.
      apply Union_Included. 
      + eapply project_var_occurs_free_ctx_alt_Included; [ eassumption | | ].
        eapply Included_trans. eapply IHe. eassumption. intros f Hfin. eapply Hun. econstructor. eassumption. now left.
        normalize_occurs_free.
        eapply Union_Included; sets.
        eapply Union_Included; sets.
        eapply Union_Included; sets.        
        do 2 eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
        eapply image_monotonic. eapply Included_Intersection_compat; sets.

        eapply Union_Included; sets.
        eapply Union_Included; sets.
        eapply Union_Included; sets.
        eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
        eapply image_monotonic. eapply Included_Intersection_compat; sets.
      + eapply Included_trans. eapply IHl. econstructor; eauto.
        intros f Hfin. eapply Hun. inv Hfin. econstructor. eassumption. right. eassumption.
        normalize_occurs_free.
        eapply Union_Included; sets.
        eapply Union_Included; sets.
        eapply Union_Included; sets.
        eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
        eapply image_monotonic. eapply Included_Intersection_compat; sets.
    - eapply project_var_occurs_free_ctx_alt_Included; [ eassumption | | sets ].
      repeat normalize_occurs_free.
      apply Union_Included. now eauto with Ensembles_DB. eapply Setminus_Included_Included_Union.
      eapply Included_trans. eapply IHe. eassumption.
      intros f Hfin. eapply Hun. now constructor.
      eapply Union_Included; [| sets ].
      eapply Union_Included; [| sets ]. now sets. 
      eapply Union_Included; sets.
      do 3 eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
      eapply image_monotonic.
      rewrite <- Intersection_Setmius_Disjoint with (S2 := [set v]). eapply Included_Intersection_compat; sets.
      now sets. now xsets. 
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      normalize_occurs_free.
      eapply Union_Included; sets.      
      eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
      eapply image_monotonic. eapply Included_Intersection_compat; sets.
    - eapply project_vars_occurs_free_ctx_alt_Included; [ eassumption | | normalize_sets; normalize_occurs_free; sets ].
      repeat normalize_occurs_free. repeat normalize_sets. 
      eapply Union_Included; sets.
      rewrite !Setminus_Union_distr.
      eapply Union_Included; sets.
      eapply Union_Included; sets. 
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      do 3 eapply Setminus_Included_Included_Union.
      eapply Included_trans. eapply IHe. eassumption.  intros g Hfin. eapply Hun. now constructor.
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      eapply Union_Included; sets. now xsets. eapply Union_Included; sets.
      do 5 eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
      eapply image_monotonic.
      rewrite <- Intersection_Setmius_Disjoint with (S2 := [set x]). eapply Included_Intersection_compat; sets.
      now sets. now xsets. 
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
      eapply image_monotonic. eapply Included_Intersection_compat; sets.
    - simpl. rewrite <- app_ctx_f_fuse. 
      eapply project_vars_occurs_free_ctx_alt_Included; [ eassumption | | ].  
      + simpl. repeat normalize_occurs_free.
        eapply Union_Included; sets. rewrite Setminus_Union_distr. 
        eapply Union_Included; sets.
        * eapply Setminus_Included_Included_Union. eapply Included_trans.
          eapply IHB. eassumption.  intros f Hfin. inv Hfin; subst; now eauto.
          eapply Included_trans. 
          eapply image_monotonic. eapply Included_Intersection_compat. reflexivity.
          eapply Union_Included; [| eapply add_global_funs_included_r; eassumption]. sets.
          do 3 eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l. 
          rewrite Intersection_commut. rewrite Intersection_Union_Disjoint. 
          rewrite Intersection_commut. eapply image_monotonic.
          eapply Included_Intersection_compat; sets. eapply occurs_free_fundefs_name_in_fundefs_Disjoint; eauto.
        * { do 2 eapply Setminus_Included_Included_Union. eapply Included_trans. eapply IHe. eassumption.
            intros f Hfin. eapply Hun. now constructor.
            eapply Union_Included; sets.
            eapply Union_Included; sets. xsets.
            - eapply Included_trans. eapply Included_Union_compat. reflexivity.
              eapply extend_fundefs'_image_Included'. 
              assert (Hsub : name_in_fundefs f2 :|: Funs \\ (Scope \\ name_in_fundefs f2) \subset
                                                                   name_in_fundefs f2 :|: (Funs \\ Scope)).
              { eapply Included_trans. rewrite !Setminus_Union_distr. eapply Included_Union_compat. 
                eapply Setminus_Setminus_Included. tci.
                eapply Setminus_Setminus_Included. tci. eapply Union_Included; sets. }
              
              eapply Union_Included; [| eapply Union_Included ]; sets.
              + eapply Included_trans. eapply image_monotonic.
                eapply Included_Intersection_compat. reflexivity. eapply Included_Union_compat.
                eassumption. reflexivity.
                eapply Included_trans
                  with (s2 :=  image σ ((occurs_free_fundefs f2 :|: (occurs_free e \\ name_in_fundefs f2)) :&: (Funs \\ Scope :|: GFuns)) :|: name_in_fundefs B'); [| xsets ].
                rewrite <- (closure_conversion_fundefs_Same_set_image) with (B2 := B'); [| eassumption ].
                rewrite <- image_Union. eapply image_monotonic.
                rewrite Union_Intersection_distr. eapply Included_Intersection_compat.
                rewrite <- !Union_assoc. eapply Included_Union_preserv_r. sets.
                rewrite <- Union_Setminus; tci; sets. 
                eapply Union_Included. sets.
                eapply Included_trans. eapply add_global_funs_included_r. eassumption. sets.
              + eapply Included_trans. eapply image_monotonic.
                eapply Included_Setminus_compat. eassumption. reflexivity.
                rewrite Setminus_Union_distr. rewrite Setminus_Same_set_Empty_set.
                xsets. }           
      + rewrite <- H1, !Union_assoc.
        normalize_occurs_free. eapply Included_Union_compat; sets.
        eapply Included_Union_compat; sets.
        eapply Included_Union_compat; sets. eapply image_monotonic.
        eapply Included_Intersection_compat; sets. 
    - eapply project_vars_occurs_free_ctx_alt_Included; [ eassumption | | normalize_sets; normalize_occurs_free; sets ].
      repeat normalize_occurs_free. repeat normalize_sets. 
      eapply Union_Included; sets.
      rewrite !Setminus_Union_distr.
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      eapply Union_Included; sets.
      do 1 eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
      eapply image_monotonic. eapply Included_Intersection_compat; sets.
    - eapply project_vars_occurs_free_ctx_alt_Included; [ eassumption | | sets ].
      repeat normalize_occurs_free.
      apply Union_Included. now eauto with Ensembles_DB. eapply Setminus_Included_Included_Union.
      eapply Included_trans. eapply IHe. eassumption.
      intros f Hfin. eapply Hun. now constructor.  
      eapply Union_Included; [| sets ].
      eapply Union_Included; [| sets ].
      now sets.
      eapply Union_Included; [| now xsets ].
      do 3 eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
      eapply image_monotonic.
      rewrite <- Intersection_Setmius_Disjoint with (S2 := [set v]). eapply Included_Intersection_compat; sets.
      sets.

      eapply Union_Included; sets.
      eapply Union_Included; sets. eapply Union_Included; sets.
      normalize_occurs_free. 
      eapply Included_Union_preserv_l. eapply Included_Union_preserv_r. eapply Included_Union_preserv_l.
      eapply image_monotonic. eapply Included_Intersection_compat; sets.
    - eapply project_var_occurs_free_ctx_alt_Included; [ eassumption | | ].
      repeat normalize_occurs_free. sets.
      repeat normalize_occurs_free. sets.
    - normalize_occurs_free. eapply Union_Included.
      + eapply Setminus_Included_Included_Union. eapply Included_trans.
        eapply IHe. eassumption.
        intros f Hfin. eapply Hun. left. now constructor.  
        rewrite occurs_free_fundefs_Fcons. normalize_sets.
        eapply Union_Included; sets.
        eapply Union_Included; sets.
        eapply Union_Included; sets.  

        eapply Included_trans with (s2 := image σ ((occurs_free e \\ (v |: (FromList l :|: name_in_fundefs f5))
                                                                :|: (occurs_free_fundefs f5 \\ [set v])) :&: (name_in_fundefs Bg :|: GFuns)) :|: [set (σ v)]
                                                :|: name_in_fundefs defs'); [| sets ].
        rewrite <- (closure_conversion_fundefs_Same_set_image) with (B2 := defs'); [| eassumption ].
        rewrite <- image_Singleton, <- !image_Union.
        rewrite !Union_Intersection_distr. eapply image_monotonic.
        rewrite <- Intersection_Setmius_Disjoint with (S2 := FromList l); sets.
        eapply Included_Intersection_compat; sets. eapply Setminus_Included_Included_Union.
        rewrite <- !Union_assoc. rewrite <- Union_Included_Union_Setminus. sets. tci. sets. sets.

        eapply Included_trans. eapply image_monotonic. eapply Setminus_Included.
        eapply Included_trans. eapply extend_fundefs'_image. sets.
      + eapply IHB in H12. eapply Setminus_Included_Included_Union. eapply Included_trans. eassumption.
        normalize_occurs_free. 
        rewrite <- image_Singleton, <- image_Union.
        rewrite Union_Intersection_distr. eapply image_monotonic. eapply Included_Intersection_compat; sets.
        rewrite <- !Union_assoc.
        rewrite <- Union_Setminus; tci; sets.
        intros x Hfun. inv Hfun; eauto.
        specialize (Hun (Fcons v t l e f5) (or_intror eq_refl)).
        now inv Hun; eauto.
    - rewrite occurs_free_fundefs_Fnil at 1. sets.
  Qed.

  Lemma Closure_conversion_occurs_free_fundefs_cor :
    (forall B GFuns {Hd : Decidable GFuns} σ c FVs B'
       (Hcc: Closure_conversion_fundefs clo_tag B GFuns σ c FVs B B')
       (Hun: fundefs_names_unique_fundefs B),
        occurs_free_fundefs B' \subset image σ (occurs_free_fundefs B :&: GFuns)).
  Proof.
    intros. eapply Closure_conversion_occurs_free_Included_alt_mut in Hcc; eauto. 
    eapply Included_trans. eassumption.
    rewrite Intersection_commut,Union_commut. rewrite Intersection_Union_Disjoint. 
    rewrite Intersection_commut. reflexivity.
    eapply occurs_free_fundefs_name_in_fundefs_Disjoint.
  Qed. 

  (* TODO move *)
  Lemma Included_Intersection_Included A (s1 s2 s3 : Ensemble A) :
    s1 \subset s3 ->
    s2 \subset s3 ->
    s1 :&: s2 :&: s3 \subset s1 :&: s2. 
  Proof.
    intros H1 H2 x Hin. inv Hin. inv H; eauto.
  Qed. 
    


  (* TODO FIX this does not hold quite like that anymore *)
  (* Lemma Closure_conversion_closed_fundefs_mut : *)
  (*   (forall e Scope Funs GFuns σ c Γ FVs e' C  *)
  (*      (Hcc : Closure_conversion clo_tag Scope Funs GFuns σ c Γ FVs e e' C) *)
  (*      (Hun: fundefs_names_unique e), *)
  (*      closed_fundefs_in_exp (C |[ e' ]|)) /\ *)
  (*   (forall B Funs GFuns σ c FVs B' *)
  (*      (Hcc: Closure_conversion_fundefs clo_tag Funs GFuns σ c FVs B B') *)
  (*      (Hun: fundefs_names_unique_fundefs B), *)
  (*      closed_fundefs_in_fundefs B'). *)
  (* Proof. *)
  (* Abort.  *)
  (*   exp_defs_induction IHe IHl IHB; intros; inv Hcc. *)
  (*   - intros B HB. rewrite project_vars_free_funs_in_exp in HB; [| eassumption ]. *)
  (*     inv HB. eapply IHe; [ eassumption | | eassumption ].  *)
  (*     intros B' H. eapply Hun. now constructor.  *)
  (*   - inv H11.  *)
  (*     intros B HB. rewrite project_var_free_funs_in_exp in HB; [| eassumption ]. *)
  (*     inv HB. inv H4. *)
  (*   - inv H11. destruct H2 as [Heq [C' [e' [Heq' Hcc']]]]. destruct y as [t e'']. *)
  (*     simpl in *; subst. *)
  (*     intros B HB. rewrite project_var_free_funs_in_exp in HB; [| eassumption ]. *)
  (*     inv HB. inv H5. *)
  (*     + inv H. eapply IHe; [ eassumption | | eassumption ]. *)
  (*       intros B' H. eapply Hun. econstructor. eassumption. now constructor.  *)
  (*     + eapply IHl. now econstructor; eauto. *)
  (*       intros B' HB'. eapply Hun. inv HB'. econstructor. eassumption. *)
  (*       constructor 2. eassumption.  *)
  (*       rewrite project_var_free_funs_in_exp. *)
  (*       econstructor; eassumption. eassumption. *)
  (*   - intros B HB. rewrite project_var_free_funs_in_exp in HB; [| eassumption ]. *)
  (*     inv HB. eapply IHe; [ eassumption | | eassumption ].  *)
  (*     intros B' H. eapply Hun. now constructor.  *)
  (*   - rewrite <- app_ctx_f_fuse. intros B HB. *)
  (*     rewrite project_vars_free_funs_in_exp in HB; [| eassumption ]. *)
  (*     inv HB. inv H9. *)
  (*     + split; [| now apply Included_Empty_set ]. *)
  (*       eapply Included_trans. *)
  (*       eapply Closure_conversion_occurs_free_Included_mut. eassumption. *)
  (*       intros B HB. eapply Hun. inv HB; eauto. *)
  (*       rewrite closure_conversion_fundefs_Same_set_image; [| eassumption ]. *)
  (*       rewrite Setminus_Same_set_Empty_set. now apply Included_Empty_set. *)
  (*     + rewrite make_closures_funs_in_exp in H10; [| eassumption ]. *)
  (*       eapply IHe; [ eassumption | | eassumption ]. *)
  (*       intros B1 HB1. eapply Hun. now constructor. *)
  (*     + eapply IHB; [ eassumption | | eassumption ]. *)
  (*       intros B1 HB1. now inv HB1; eauto. *)
  (*   - intros B HB.  rewrite project_vars_free_funs_in_exp in HB; [| eassumption ]. *)
  (*     inv HB. inv H1. inv H4. *)
  (*   - intros B HB. rewrite project_vars_free_funs_in_exp in HB; [| eassumption ]. *)
  (*     inv HB. eapply IHe; [ eassumption | | eassumption ].  *)
  (*     intros B' H. eapply Hun. now constructor. *)
  (*   - intros B HB. rewrite project_var_free_funs_in_exp in HB; [| eassumption ]. *)
  (*     inv HB. *)
  (*   - intros B HB. inv HB. *)
  (*     + eapply IHe; [ eassumption | | eassumption ].   *)
  (*       intros B' H. eapply Hun. left. now constructor.  *)
  (*     + eapply IHB; [ eassumption | | eassumption ]. *)
  (*       intros B' H. inv H; eauto. *)
  (*       specialize (Hun (Fcons v t l e f5) (or_intror eq_refl)). now inv Hun; eauto. *)
  (*   - intros B HB. inv HB. *)
  (* Qed. *)


  (* TODO : move *)
  Lemma inclusion_trans {A} P1 P2 P3 :
    inclusion A P1 P2 ->
    inclusion A P2 P3 ->
    inclusion A P1 P3.
  Proof.
    now firstorder. 
  Qed.

  (** * Lemmas about [Closure_conversion_fundefs] *)
  
  Lemma closure_conversion_fundefs_find_def σ c Bg GFuns FVs B1 B2 f t1 xs e1 :
    injective_subdomain (name_in_fundefs B1) σ ->
    Closure_conversion_fundefs clo_tag Bg GFuns σ c FVs B1 B2 ->
    find_def f B1 = Some (t1, xs, e1) ->
    exists Γ' C e2,
      ~ In var (Union var (image σ (name_in_fundefs Bg :|: GFuns)) (Union _ (FromList xs) (bound_var e1))) Γ' /\
      find_def (σ f) B2 = Some (t1, Γ' :: xs, (C |[ e2 ]|)) /\
      Closure_conversion clo_tag (FromList xs) (name_in_fundefs Bg) (GFuns \\ (FromList xs)) σ c
                         (extend_fundefs' id Bg Γ')  Γ' FVs e1 e2 C.
  Proof.
    intros Hinj Hcc Hdef. induction Hcc.
    - simpl in Hdef. destruct (M.elt_eq f f0) eqn:Heq; subst.
      + inv Hdef. repeat eexists; eauto. 
        simpl. 
        intros Hc. eapply H. now eauto.
        simpl. rewrite peq_true. reflexivity.
      + edestruct IHHcc as [Γ'' [C' [e2 [Hnin [Hfind Hcc']]]]]; eauto.
        eapply injective_subdomain_antimon. eassumption.
        now apply Included_Union_r.
        repeat eexists; eauto. simpl. rewrite peq_false. eassumption.
        intros Hc. eapply n. eapply Hinj; eauto.
        right. eapply fun_in_fundefs_name_in_fundefs.
        eapply find_def_correct. now eauto.
        left; eauto.
    - inv Hdef.
  Qed.


  (** * Lemmas about [project_var] and [project_vars] *)

  Lemma project_var_free_set_Included Scope Funs GFuns σ c genv Γ FVs x x' C S S' :
    project_var clo_tag Scope GFuns Funs σ c genv Γ FVs S x x' C S' ->
    Included _ S' S.
  Proof with now eauto with Ensembles_DB.
    intros Hproj. inv Hproj...
  Qed.

  Lemma project_vars_free_set_Included Scope Funs GFuns σ c genv Γ FVs xs xs' C S S' :
    project_vars clo_tag Scope Funs GFuns σ c genv Γ FVs S xs xs' C S' ->
    Included _ S' S.
  Proof.
    intros Hproj. induction Hproj.
    - now apply Included_refl.
    - eapply Included_trans. eassumption.
      eapply project_var_free_set_Included. eassumption. 
  Qed.

  Lemma project_var_not_In_free_set Scope Funs GFuns σ c genv Γ FVs x x' C S S'  :
    project_var clo_tag Scope Funs GFuns σ c genv Γ FVs S x x' C S' ->
    Disjoint _ S (Scope :|: (image σ ((Funs \\ Scope) :|: GFuns) :|:
                                   ((FromList FVs) :|: ([set Γ])))) ->
    ~ In _ S' x'.
  Proof.
    intros Hproj Hd. inv Hproj; intros Hc.
    - eapply Hd. eauto.
    - inv Hc. exfalso. eauto.
    - inv Hc. inv H4; eauto. 
    - inv Hc; eauto.
  Qed.

  Lemma project_vars_not_In_free_set Scope Funs GFuns σ c genv Γ FVs xs xs' C S S'  :
    project_vars clo_tag Scope Funs GFuns σ c genv Γ FVs S xs xs' C S' ->
    Disjoint _ S (Scope :|: (image σ ((Funs \\ Scope) :|: GFuns) :|:
                                   ((FromList FVs) :|: ([set Γ]))))  ->
    Disjoint _ S' (FromList xs').
  Proof.
    intros Hproj Hd. induction Hproj.
    - constructor. intros x Hc. inv Hc. rewrite FromList_nil in H0.
      eapply not_In_Empty_set. eassumption. 
    - rewrite FromList_cons. eapply Disjoint_sym.
      eapply Union_Disjoint_l.
      + eapply Disjoint_Included_r_sym.
        eapply project_vars_free_set_Included; eassumption.
        eapply Disjoint_Singleton_r.
        eapply project_var_not_In_free_set; eassumption.        
      + eapply Disjoint_sym. eapply IHHproj.
        eapply Disjoint_Included_l.
        eapply project_var_free_set_Included. eassumption.
        eassumption.
  Qed.

  Lemma project_var_get Scope Funs GFuns σ c genv Γ FVs S1 x x' C1 S2 rho1 rho2 y:
    project_var clo_tag Scope Funs GFuns σ c genv Γ FVs S1 x x' C1 S2 ->
    ctx_to_rho C1 rho1 rho2 ->
    ~ In _ S1 y ->
    M.get y rho1 = M.get y rho2. 
  Proof.
    intros Hvar Hctx Hin. inv Hvar.
    - inv Hctx. reflexivity.
    - inv Hctx. inv H9.
      destruct (peq y x'); subst.
      contradiction.
      now rewrite M.gso.
    - inv Hctx. inv H11. inv H13.
      destruct (peq y x'); subst.
      contradiction. rewrite M.gso; eauto.
      destruct (peq y g_env); subst.
      exfalso. now inv H3; eauto.
      now rewrite M.gso; eauto.
    - inv Hctx; inv H12.
      destruct (peq y x'); subst.
      contradiction. inv H13.
      now rewrite M.gso.
  Qed.

  Lemma project_vars_get Scope Funs GFuns σ c genv Γ FVs S1 xs xs' C1 S2 rho1 rho2 y:
    project_vars clo_tag Scope Funs GFuns σ c genv Γ FVs S1 xs xs' C1 S2 ->
    ctx_to_rho C1 rho1 rho2 ->
    ~ In _ S1 y ->
    M.get y rho1 = M.get y rho2. 
  Proof.
    revert Scope Funs Γ FVs S1 xs' C1 S2 rho1 rho2 y.
    induction xs; intros Scope Funs Γ FVs S1 xs' C1 S2 rho1 rho2 y Hproj Hctx Hnin.
    - inv Hproj. inv Hctx. reflexivity.
    - inv Hproj.  
      edestruct ctx_to_rho_comp_ctx_l as [rho'' [Hctx1 Hctx2]]; eauto.
      rewrite <- comp_ctx_f_correct. reflexivity.
      eapply project_var_get in Hctx1; eauto. 
      eapply IHxs in Hctx2; eauto.
      rewrite Hctx1, <- Hctx2. reflexivity.
      intros Hc. eapply Hnin.
      eapply project_var_free_set_Included; eassumption.
  Qed.

  Lemma project_var_get_list Scope Funs GFuns σ c genv Γ FVs S1 x x' C1 S2 rho1 rho2 ys :
    project_var clo_tag Scope Funs GFuns σ c genv Γ FVs S1 x x' C1 S2 ->
    ctx_to_rho C1 rho1 rho2 ->
    Disjoint _ S1 (FromList ys) ->
    get_list ys rho1 = get_list ys rho2. 
  Proof.
    revert rho1 rho2; induction ys; intros rho1 rho2  Hproj Hctx Hnin.
    - reflexivity. 
    - simpl.
      rewrite FromList_cons in Hnin. eapply Disjoint_sym in Hnin. 
      erewrite project_var_get; eauto.
      erewrite IHys; eauto.
      eapply Disjoint_sym. eapply Disjoint_Union_r. eassumption.
      intros Hc. eapply Hnin. eauto.
  Qed.

  Lemma project_vars_get_list Scope Funs GFuns σ c genv Γ FVs S1 xs xs' C1 S2 rho1 rho2 ys :
    project_vars clo_tag Scope Funs GFuns σ c genv Γ FVs S1 xs xs' C1 S2 ->
    ctx_to_rho C1 rho1 rho2 ->
    Disjoint _ S1 (FromList ys) ->
    get_list ys rho1 = get_list ys rho2. 
  Proof.
    revert rho1 rho2; induction ys; intros rho1 rho2  Hproj Hctx Hnin.
    - reflexivity. 
    - simpl.
      rewrite FromList_cons in Hnin. eapply Disjoint_sym in Hnin. 
      erewrite project_vars_get; eauto.
      erewrite IHys; eauto.
      eapply Disjoint_sym. eapply Disjoint_Union_r. eassumption.
      intros Hc. eapply Hnin. eauto.
  Qed.        

  Lemma project_var_not_In Scope Funs GFuns σ c genv Γ FVs S x x' C S' :
    Disjoint _ S (Union var Scope
                        (Union var (Funs :|: GFuns)
                               (Union var (FromList FVs) (Singleton var Γ)))) ->
    
    project_var clo_tag Scope Funs GFuns σ c genv Γ FVs S x x' C S' ->
    ~ In _ S x.
  Proof.
    intros Hd  Hproj. inv Hproj; intros Hin; try now eapply Hd; eauto.
    eapply nthN_In in H2. eapply Hd. eauto.
  Qed.

  Lemma project_vars_Disjoint Scope Funs GFuns σ c genv Γ FVs S xs xs' C S' :
    Disjoint _ S (Union var Scope
                        (Union var (Funs :|: GFuns)
                               (Union var (FromList FVs) (Singleton var Γ)))) ->      
    project_vars clo_tag Scope Funs GFuns σ c genv Γ FVs S xs xs' C S' ->
    Disjoint _ S (FromList xs).
  Proof.
    revert xs' C S S'; induction xs; intros xs' C S S' Hd Hproj.
    - rewrite FromList_nil. now eapply Disjoint_Empty_set_r.
    - inv Hproj. rewrite FromList_cons. 
      eapply Union_Disjoint_r.
      eapply Disjoint_Singleton_r. eapply project_var_not_In; eauto.
      inv H10.
      + eapply IHxs; [| eassumption ]. eauto.
      + assert (Hd1 : Disjoint _ (Setminus var S (Singleton var y'))
                               (FromList xs))
          by (eapply IHxs; eauto with Ensembles_DB).
        eapply project_vars_In_Union in H14.
        eapply Disjoint_Included_r. eassumption.
        eauto 10 with Ensembles_DB.
      + assert (Hd1 : Disjoint _  (S \\ [set y'] \\ [set g_env])
                               (FromList xs))
          by (eapply IHxs; eauto with Ensembles_DB).
        eapply project_vars_In_Union in H14.
        eapply Disjoint_Included_r. eassumption.
        eauto 10 with Ensembles_DB.
      + assert (Hd1 : Disjoint _ (Setminus var S (Singleton var y'))
                               (FromList xs))
          by (eapply IHxs; eauto with Ensembles_DB).
        eapply project_vars_In_Union in H14.
        eapply Disjoint_Included_r. eassumption.
        eauto 10 with Ensembles_DB.
  Qed.

  (** Properties about context sizes *)

  Lemma project_var_sizeOf_ctx_exp (Scope Funs GFuns : Ensemble var) (σ : var -> var) 
        (c : ctor_tag) genv (Γ : var) (FVs : list var) (S : Ensemble var) 
    (x x' : var) (C : exp_ctx) (S' : Ensemble var) :
    project_var clo_tag Scope Funs GFuns σ c genv Γ FVs S x x' C S' ->
    sizeOf_exp_ctx C <= 4. 
  Proof.
    intros Hctx. inv Hctx; eauto.
  Qed.
  
  Lemma project_vars_sizeOf_ctx_exp (Scope Funs GFuns : Ensemble var) (σ : var -> var) 
    (c : ctor_tag) genv (Γ : var) (FVs : list var) (S : Ensemble var) 
    (xs xs' : list var) (C : exp_ctx) (S' : Ensemble var)  :
    project_vars clo_tag Scope Funs GFuns σ c genv Γ FVs S xs xs' C S' ->
    sizeOf_exp_ctx C <= 4 * length xs. 
  Proof.
    intros Hctx. induction Hctx; eauto.
    rewrite sizeOf_exp_ctx_comp_ctx. simpl.
    specialize (project_var_sizeOf_ctx_exp _ _ _ _ _ _ _ _ _ _ _ _ _ H).
    omega.
  Qed.

  Lemma make_closures_sizeOf_ctx_exp (B : fundefs) (S : Ensemble var) (Γ : var)
        (C : exp_ctx) (σ  : var -> var) (S' : Ensemble var) :
    make_closures clo_tag B S Γ C σ S' ->
    sizeOf_exp_ctx C <= 3 * numOf_fundefs B.
  Proof.
    induction 1; eauto.
    simpl. specialize (sizeOf_exp_grt_1 e).
    omega.
  Qed.

  Lemma Closure_conversion_fundefs_numOf_fundefs Funs (GFuns : Ensemble var) (σ : var -> var) (c : ctor_tag) 
        (FVs : list var) (B1 B2 : fundefs) :
    Closure_conversion_fundefs clo_tag Funs GFuns σ c FVs B1 B2 ->
    numOf_fundefs B1 = numOf_fundefs B2.
  Proof.
    intros Hcc; induction Hcc; eauto; simpl. congruence.
  Qed.

  Lemma project_var_tag_inv Scope GFuns Funs σ c1 c2 genv Γ  S x x' C S' :
    project_var clo_tag Scope GFuns Funs σ c1 genv Γ [] S x  x' C S' ->
    project_var clo_tag Scope GFuns Funs σ c2 genv Γ [] S x  x' C S'.
  Proof.
    intros Hc; inv Hc; (try constructor; eauto).
    inv H2.
  Qed.

  Lemma project_vars_tag_inv Scope GFuns Funs σ c1 c2 genv Γ  S x x' C S' :
    project_vars clo_tag Scope GFuns Funs σ c1 genv Γ [] S x  x' C S' ->
    project_vars clo_tag Scope GFuns Funs σ c2 genv Γ [] S x  x' C S'.
  Proof.
    revert Scope GFuns Funs σ c1 c2 Γ  S x' C S'; induction x;
      intros Scope GFuns Funs σ c1 c2 Γ  S x' C S' Hvs; inv Hvs; try (constructor; eauto).
    econstructor. eapply project_var_tag_inv. eassumption.
    eapply IHx; eassumption.
  Qed.

  Lemma Closure_conversion_tag_inv Scope Funs GFuns g c1 c2 genv Γ e e' C :
    Closure_conversion clo_tag Scope Funs GFuns g c1 genv Γ [] e e' C ->
    Closure_conversion clo_tag Scope Funs GFuns g c2 genv Γ [] e e' C.
  Proof.
    revert Scope Funs GFuns g c1 c2 genv Γ e' C; induction e using exp_ind';
      intros Scope Funs GFuns g c1 c2 genv Γ e' C Hcc; inv Hcc;
        try (econstructor; eauto; eapply project_vars_tag_inv; eassumption);
        try (econstructor; eauto; eapply project_var_tag_inv; eassumption).
    - econstructor; eauto.
      eapply project_var_tag_inv. eassumption. inv H13.
      constructor.
    - econstructor; eauto.
      eapply project_var_tag_inv. eassumption.
      inv H13. destruct H2 as [Heq [C' [e' [HeqC Hcc']]]].
      destruct y as [c2' e2]. simpl in *; subst.
      constructor; eauto.
      split; eauto. do 2 eexists; split; eauto. simpl. reflexivity.
      assert (Hcc1 : Closure_conversion clo_tag Scope Funs GFuns g c2 genv Γ [] (Ecase v l) (Ecase x' l') C).
      { eapply IHe0. econstructor; eauto. }
      inv Hcc1. eassumption.
  Qed.



End Closure_conversion_util.
