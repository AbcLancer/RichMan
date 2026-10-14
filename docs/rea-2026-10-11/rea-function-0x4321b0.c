
void __thiscall FUN_004321b0(void *this,double param_1)

{
  float fVar1;
  double dVar2;
  int iVar3;
  float10 fVar4;
  longlong lVar5;
  float local_24;
  float local_20;
  float local_1c;
  float local_18 [4];
  float local_8;
  
  if (3.0 < *(float *)((int)this + 0x38)) {
    if (*(float *)((int)this + 0x38) == *(float *)((int)this + 0x34)) {
      *(undefined4 *)((int)this + 0x1c) = 2;
    }
    else {
      *(undefined4 *)((int)this + 0x1c) = 0;
    }
  }
  else {
    *(undefined4 *)((int)this + 0x1c) = 1;
  }
  local_24 = 0.0;
  local_20 = 0.0;
  local_1c = 0.0;
  local_18[0] = -56.0;
  local_18[1] = 120.0;
  local_18[2] = -56.0;
  FUN_00404020((void *)(*(int *)(*(int *)this + 0xc) + 0x28),local_18,&local_24);
  fVar1 = (float)param_1 * 100.0 * 0.16666667;
  if (1.0 < fVar1) {
    fVar1 = 1.0;
  }
  local_18[3] = (local_24 - *(float *)((int)this + 0x54)) * fVar1;
  local_8 = (local_20 - *(float *)((int)this + 0x58)) * fVar1;
  *(float *)((int)this + 0x54) = local_18[3] + *(float *)((int)this + 0x54);
  *(float *)((int)this + 0x58) = local_8 + *(float *)((int)this + 0x58);
  *(float *)((int)this + 0x5c) =
       (local_1c - *(float *)((int)this + 0x5c)) * fVar1 + *(float *)((int)this + 0x5c);
  *(float *)((int)this + 0x18) = (float)param_1 + *(float *)((int)this + 0x18);
  fVar4 = FUN_00432360(*(int *)((int)this + 0x20));
  if ((float10)*(int *)((int)this + 0x24) * fVar4 <=
      (float10)*(float *)((int)this + 0x18) - (float10)*(double *)((int)this + 0x28)) {
    FUN_004323a0(this,0,0x7fffffff);
  }
  if (*(int *)((int)this + 0x20) == 0) {
    iVar3 = FUN_00405130(10,0x14);
    lVar5 = __ftol();
    if (iVar3 < (int)lVar5) {
      iVar3 = FUN_00405130(1,3);
      FUN_004323a0(this,1,iVar3);
    }
  }
  if ((*(int *)((int)this + 0x44) != 0) &&
     (dVar2 = *(double *)((int)this + 0x48) - param_1, *(double *)((int)this + 0x48) = dVar2,
     dVar2 <= 0.0)) {
    *(undefined4 *)((int)this + 0x44) = 0;
  }
  return;
}

