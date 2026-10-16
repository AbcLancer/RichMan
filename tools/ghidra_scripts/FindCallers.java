// FindCallers.java —— 找「谁调用了这个函数」，并附带调用点附近的指令
//
// 用途：像 FUN_00435f80（状态写入，第 2 个参数就是状态编号）这种函数，
// 只要看**每个调用点前面压栈的那个常量**，就能反推出「状态号 → 什么效果」的完整映射。
//
// 用法：
//   -scriptPath "<项目>/tools/ghidra_scripts" \
//   -postScript FindCallers.java <输出文件> <目标地址> [附近指令条数]
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.symbol.Reference;
import java.io.FileWriter;

public class FindCallers extends GhidraScript {

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 2) {
            println("用法: FindCallers.java <输出文件> <目标地址> [附近指令条数]");
            return;
        }
        int ctx = (args.length > 2) ? Integer.parseInt(args[2]) : 6;
        Address target = currentProgram.getAddressFactory().getAddress(args[1]);
        Function tf = getFunctionContaining(target);

        FileWriter w = new FileWriter(args[0], false);
        w.write("// 目标: " + args[1]
                + (tf == null ? "（不在已知函数内）" : " → " + tf.getName() + " @ " + tf.getEntryPoint())
                + "\n\n");

        int n = 0;
        for (Reference ref : getReferencesTo(target)) {
            if (!ref.getReferenceType().isCall()) {
                continue;
            }
            n++;
            Address from = ref.getFromAddress();
            Function caller = getFunctionContaining(from);
            w.write("// [" + n + "] 调用点 " + from
                    + "   位于 " + (caller == null ? "(无函数)" : caller.getName()
                            + " @ " + caller.getEntryPoint())
                    + "\n");

            // 从调用点往回数 ctx 条指令（参数通常就是在这些 push 里压进去的）
            Instruction ins = getInstructionAt(from);
            java.util.ArrayList<Instruction> back = new java.util.ArrayList<>();
            Instruction p = (ins == null) ? null : ins.getPrevious();
            for (int i = 0; i < ctx && p != null; i++) {
                back.add(0, p);
                p = p.getPrevious();
            }
            for (Instruction b : back) {
                w.write("//     " + b.getAddress() + "  " + b.toString() + "\n");
            }
            w.write("//   > " + (ins == null ? "(无指令)" : ins.toString()) + "\n\n");
        }
        w.write("// 共找到 " + n + " 个调用点\n");
        w.close();
        println("FindCallers 完成，调用点 " + n + " 个 → " + args[0]);
    }
}
