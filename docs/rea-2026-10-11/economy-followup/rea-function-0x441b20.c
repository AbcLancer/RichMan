
void __thiscall FUN_00441b20(void *this,void *param_1)

{
  int *piVar1;
  char *pcVar2;
  uint *puVar3;
  int iVar4;
  int *piVar5;
  void *this_00;
  int iVar6;
  char local_244 [4];
  byte local_240 [64];
  char local_200 [256];
  char local_100 [256];
  
  FUN_004026c0(DAT_004a6040,local_244,4,(int)param_1);
  piVar1 = (int *)((int)this + 0x24);
  FUN_004026c0(DAT_004a6040,(char *)piVar1,4,(int)param_1);
  pcVar2 = (char *)FUN_00402090(param_1,local_200,0x100);
  FUN_00406cf0(pcVar2);
  FUN_00485290(local_200,(byte *)s__ssound_effect__0049eed8);
  FUN_004064a0(local_200);
  FUN_00402090(param_1,local_100,0x100);
  FUN_00485290(local_200,(byte *)s__sanim_allanim_txt_0049eec4);
  puVar3 = FUN_00402430(DAT_004a6040,local_200,0x401);
  FUN_00402c20(DAT_004a6040,(char *)local_240,0x40,(int)puVar3);
  iVar4 = FUN_00485c79(this_00,local_240);
  *piVar1 = iVar4;
  piVar5 = operator_new(iVar4 * 0xc + 4);
  if (piVar5 == (int *)0x0) {
    piVar5 = (int *)0x0;
  }
  else {
    *piVar5 = *piVar1;
    piVar5 = piVar5 + 1;
  }
  *(int **)((int)this + 0x28) = piVar5;
  iVar4 = 0;
  if (0 < *piVar1) {
    iVar6 = 0;
    do {
      FUN_00402c20(DAT_004a6040,local_200,0x100,(int)puVar3);
      FUN_00486797(local_200,&DAT_0049eebc);
      FUN_00402090(param_1,local_100,0x100);
      FUN_00485290(local_200,(byte *)s__sanim__s_0049eeb0);
      FUN_00441960((void *)(*(int *)((int)this + 0x28) + iVar6),local_200,0);
      iVar4 = iVar4 + 1;
      iVar6 = iVar6 + 0xc;
    } while (iVar4 < *piVar1);
  }
  FUN_00402660(DAT_004a6040,puVar3);
  FUN_00406cf0((char *)0x0);
  FUN_004064a0((char *)0x0);
  return;
}

