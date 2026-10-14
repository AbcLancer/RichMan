
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __cdecl FUN_00438d70(int param_1,void *param_2)

{
  int *piVar1;
  void *this;
  int iVar2;
  void *this_00;
  int iVar3;
  byte *pbVar4;
  int iVar5;
  longlong lVar6;
  
  this_00 = param_2;
  iVar2 = param_1;
  iVar5 = *(int *)(*(int *)(param_1 + 0x30) + 0x38);
  iVar3 = *(int *)(*(int *)(param_1 + 0x30) + 0x34);
  _DAT_004fdb20 = param_2;
  if (iVar5 == 3) {
    this = *(void **)((int)param_2 + 0x1c0);
    if (*(void **)(param_1 + 0x34) == this) {
      return;
    }
    param_1 = *(int *)(*(int *)((int)param_2 + 0xc) + 0x8c);
    if (iVar3 == 1) {
      iVar5 = *(int *)((int)param_2 + 0x114);
      if (param_1 <= *(int *)((int)param_2 + 0x114)) {
        iVar5 = param_1;
      }
      if (iVar5 == 0) {
        return;
      }
      FUN_00434c40(param_2,0,(short *)0x0,-iVar5);
      FUN_00434ae0(*(void **)(*(int *)(iVar2 + 0x34) + 0x2e0),0,(short *)0x0,iVar5);
      _DAT_004fdb34 = (byte *)iVar5;
      FUN_0042ab30(&DAT_005090b0,0x1f41,(int *)&DAT_004fdb20);
      return;
    }
    if (iVar3 == 2) {
      lVar6 = __ftol();
      pbVar4 = (byte *)lVar6;
      if (pbVar4 == (byte *)0x0) {
        return;
      }
      FUN_0043ff30(this,pbVar4,0);
      FUN_0043ffe0(*(void **)(iVar2 + 0x34),pbVar4,0);
      _DAT_004fdb34 = pbVar4;
      FUN_0042ab30(&DAT_005090b0,0x1f42,(int *)&DAT_004fdb20);
      return;
    }
    if (iVar3 != 3) {
      return;
    }
    pbVar4 = (byte *)(param_1 * 10000);
    if (pbVar4 == (byte *)0x0) {
      return;
    }
    FUN_0043ff30(this,pbVar4,0);
    FUN_0043ffe0(*(void **)(iVar2 + 0x34),pbVar4,0);
    FUN_00436a10(this_00,2,0x30);
    _DAT_004fdb34 = pbVar4;
    FUN_0042ab30(&DAT_005090b0,0x1f43,(int *)&DAT_004fdb20);
    return;
  }
  if (iVar5 == 4) {
    if (iVar3 == 1) {
      iVar5 = DAT_0049e96c - *(int *)((int)param_2 + 0x178);
      FUN_00434350(param_2,iVar5);
      _DAT_004fdb34 = (byte *)iVar5;
      FUN_0042ab30(&DAT_005090b0,0x1f44,(int *)&DAT_004fdb20);
      return;
    }
    if (iVar3 != 2) {
      if (iVar3 != 3) {
        return;
      }
      FUN_0042ab30(&DAT_005090b0,0x1f46,(int *)&DAT_004fdb20);
      FUN_00434350(this_00,DAT_0049e96c);
      iVar5 = FUN_00435630(this_00,0xff);
      if (iVar5 == -1) {
        return;
      }
      iVar5 = FUN_00435630(this_00,0xff);
      iVar5 = FUN_00433040(&DAT_004e3b18,iVar5);
      FUN_00432440(iVar5);
      return;
    }
    if (*(int *)((int)param_2 + 0x1c0) == *(int *)(param_1 + 0x34)) {
      return;
    }
    iVar5 = FUN_0042eb40(&DAT_004e3820,*(int *)(param_1 + 0x34),4,2);
    if (iVar5 == 0) {
      return;
    }
    if (5 < iVar5) {
      iVar5 = 5;
    }
    param_1 = iVar5 + -1;
    FUN_00485ce0();
    lVar6 = __ftol();
    pbVar4 = (byte *)((int)lVar6 * 10000);
    if (160000 < (int)pbVar4) {
      pbVar4 = (byte *)0x27100;
    }
    FUN_0043ff30(*(void **)((int)this_00 + 0x1c0),pbVar4,0);
    FUN_0043ffe0(*(void **)(iVar2 + 0x34),pbVar4,0);
    _DAT_004fdb34 = pbVar4;
    FUN_0042ab30(&DAT_005090b0,0x1f45,(int *)&DAT_004fdb20);
    return;
  }
  if (iVar5 != 5) {
    return;
  }
  if (iVar3 == 1) {
    FUN_0042ab30(&DAT_005090b0,0x1f47,(int *)&DAT_004fdb20);
    return;
  }
  if (iVar3 == 2) {
    iVar5 = FUN_00435630(param_2,0xff);
    if (iVar5 == -1) {
      return;
    }
    iVar5 = FUN_00435630(this_00,0xff);
    iVar5 = FUN_00433040(&DAT_004e3b18,iVar5);
    FUN_00432440(iVar5);
    FUN_0042ab30(&DAT_005090b0,0x1f48,(int *)&DAT_004fdb20);
    return;
  }
  if (iVar3 != 3) {
    return;
  }
  piVar1 = (int *)(param_1 + 0x34);
  param_1 = -1;
  if (*(int *)((int)param_2 + 0x1c0) == *piVar1) {
    iVar5 = FUN_00405130(1,3);
    if (iVar5 == 1) {
      iVar3 = FUN_0041ed50(&DAT_004e48b8,2,(short *)&param_1,1);
      if (iVar3 == 0) {
LAB_004390e8:
        param_1 = FUN_0041ee80(&DAT_004e48b8,0x28);
        goto LAB_004390f8;
      }
LAB_004390fd:
      if (-1 < (short)param_1) goto LAB_00439121;
    }
    else {
      if (iVar5 == 2) goto LAB_004390e8;
LAB_004390f8:
      if (iVar5 != 3) goto LAB_004390fd;
    }
    param_1 = FUN_0041ee80(&DAT_004e48b8,0x29);
    if ((short)param_1 < 0) goto LAB_0043912a;
  }
  else {
    iVar5 = FUN_0041ed50(&DAT_004e48b8,-1,(short *)&param_1,1);
    if (iVar5 == 0) goto LAB_0043912a;
  }
LAB_00439121:
  FUN_00434ae0(this_00,1,(short *)&param_1,0);
LAB_0043912a:
  _DAT_004fdb38 = FUN_0041f010(&DAT_004e48b8,(int)(short)param_1);
  FUN_0042ab30(&DAT_005090b0,0x1f49,(int *)&DAT_004fdb20);
  return;
}

