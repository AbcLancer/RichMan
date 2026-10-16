// ===== 435620 → FUN_00435620 @ 00435620（就是入口）  大小 7 字节

undefined4 __fastcall FUN_00435620(int param_1)

{
  return *(undefined4 *)(param_1 + 0x1c0);
}



// ===== 42bb50 → FUN_0042bb50 @ 0042bb50（就是入口）  大小 22 字节

int __fastcall FUN_0042bb50(int param_1)

{
  int iVar1;
  
  if (*(void **)(param_1 + 0x28) == (void *)0x0) {
    return 0;
  }
  iVar1 = FUN_0042b1b0(*(void **)(param_1 + 0x28),*(int *)(param_1 + 0x2c));
  return iVar1;
}



// ===== 436080 → FUN_00436080 @ 00436080（就是入口）  大小 137 字节

undefined * __fastcall FUN_00436080(int param_1)

{
  int iVar1;
  uint uVar2;
  int *piVar3;
  int *piVar4;
  int *piVar5;
  int local_44;
  int local_40 [16];
  
  iVar1 = 0;
  local_44 = 0;
  if (0 < DAT_004f2a10) {
    piVar3 = local_40 + 1;
    piVar5 = (int *)(param_1 + 0x19c);
    piVar4 = &DAT_004f1cd0;
    do {
      if ((*piVar4 != 0) && (*piVar4 != *(int *)(param_1 + 0x1c0))) {
        piVar3[-1] = *piVar5;
        local_44 = local_44 + 1;
        *piVar3 = iVar1;
        piVar3 = piVar3 + 2;
      }
      iVar1 = iVar1 + 1;
      piVar5 = piVar5 + 1;
      piVar4 = piVar4 + 0x78;
    } while (iVar1 < DAT_004f2a10);
    if (local_44 != 0) {
      uVar2 = FUN_00405100();
      return &DAT_004f1b10 + local_40[((int)uVar2 % local_44) * 2 + 1] * 0x1e0;
    }
  }
  return (undefined *)0x0;
}



// ===== 41ce40 → FUN_0041ce40 @ 0041ce40（就是入口）  大小 61 字节

bool __thiscall FUN_0041ce40(void *this,int param_1)

{
  if (param_1 == 0) {
    return false;
  }
  return *(int *)((int)this +
                 (*(int *)(param_1 + 0x30) +
                 (*(int *)(param_1 + 0x38) * 3 + *(int *)(param_1 + 0x34)) * 10) * 0x58 + -0x338) !=
         -1;
}



// ===== 405130 → FUN_00405130 @ 00405130（就是入口）  大小 62 字节

int __cdecl FUN_00405130(int param_1,int param_2)

{
  DAT_004acce8 = DAT_004acce8 * 0x343fd + 0x269ec3;
  return (int)((longlong)(ulonglong)(DAT_004acce8 >> 0x10 & 0x7fff) %
              (longlong)((param_2 - param_1) + 1)) + param_1;
}



// ===== 42bb70 → FUN_0042bb70 @ 0042bb70（就是入口）  大小 24 字节

void FUN_0042bb70(undefined4 param_1,int param_2)

{
  for (; param_2 != 0; param_2 = param_2 + -1) {
  }
  return;
}



// ===== 42ec80 → FUN_0042ec80 @ 0042ec80（就是入口）  大小 86 字节

int __thiscall FUN_0042ec80(void *this,int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  int iVar3;
  
  iVar2 = 0;
  iVar3 = 0;
  if (*(int *)((int)this + 0x20) < 1) {
    return 0;
  }
  do {
    iVar1 = FUN_0042bb50(*(int *)(*(int *)((int)this + 0x24) + iVar3 * 4));
    if (((iVar1 != 0) && ((param_2 == 0 || (*(int *)(iVar1 + 0x34) == param_2)))) &&
       ((param_1 == 0 || (*(int *)(iVar1 + 0x30) != 0)))) {
      iVar2 = iVar2 + 1;
    }
    iVar3 = iVar3 + 1;
  } while (iVar3 < *(int *)((int)this + 0x20));
  return iVar2;
}



// ===== 421240 → FUN_00421240 @ 00421240（就是入口）  大小 150 字节

undefined4 __cdecl FUN_00421240(void *param_1,int param_2)

{
  bool bVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  undefined3 extraout_var;
  int *piVar5;
  
  iVar2 = FUN_00436230(param_1,3);
  if (iVar2 == 0) {
    return 0;
  }
  iVar2 = FUN_0042bb70(*(undefined4 *)(*(int *)((int)param_1 + 0xc) + 0x74),param_2);
  iVar3 = FUN_0042bb50(iVar2);
  if (iVar3 == 0) {
    return 0;
  }
  iVar4 = FUN_00435620((int)param_1);
  if (*(int *)(iVar3 + 0x34) != iVar4) {
    return 0;
  }
  bVar1 = FUN_0041ce40(&DAT_004ece18,*(int *)(iVar3 + 0x30));
  if (CONCAT31(extraout_var,bVar1) == 0) {
    return 0;
  }
  if (-1 < *(int *)(iVar2 + 0x34)) {
    piVar5 = (int *)FUN_00431ac0(&DAT_004f2e68,*(int *)(iVar2 + 0x34));
    if ((*piVar5 == 9) || (*piVar5 == 8)) {
      return 0;
    }
  }
  return 1;
}



// ===== 42bb90 → FUN_0042bb90 @ 0042bb90（就是入口）  大小 83 字节

int __thiscall FUN_0042bb90(void *this,int param_1,int param_2,int param_3)

{
  int iVar1;
  int iVar2;
  
  iVar2 = 0;
  do {
    if ((param_1 == 0) || (this = *(void **)((int)this + param_2 * 4 + 0x20), this == (void *)0x0))
    {
      return iVar2;
    }
    iVar1 = FUN_0042bb50((int)this);
    if (iVar1 != 0) {
      if (param_3 == 0) {
        if (*(int *)(iVar1 + 0x34) == 0) goto LAB_0042bbd3;
      }
      else if (*(int *)(iVar1 + 0x34) == *(int *)(param_3 + 0x1c0)) {
LAB_0042bbd3:
        iVar2 = iVar2 + 1;
      }
    }
    param_1 = param_1 + -1;
  } while( true );
}



// ===== 42bbf0 → FUN_0042bbf0 @ 0042bbf0（就是入口）  大小 71 字节

int __thiscall FUN_0042bbf0(void *this,int param_1,int param_2,int param_3)

{
  int iVar1;
  int iVar2;
  
  iVar2 = 0;
  while ((param_1 != 0 && (this = *(void **)((int)this + param_2 * 4 + 0x20), this != (void *)0x0)))
  {
    iVar1 = FUN_0042bb50((int)this);
    if ((iVar1 != 0) &&
       ((*(int *)(iVar1 + 0x34) != 0 && (*(int *)(iVar1 + 0x34) != *(int *)(param_3 + 0x1c0))))) {
      iVar2 = iVar2 + 1;
    }
    param_1 = param_1 + -1;
  }
  return iVar2;
}



