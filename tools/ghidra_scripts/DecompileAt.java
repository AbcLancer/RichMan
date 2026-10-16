// DecompileAt.java —— 定点反编译：只取命令行里点名的那些地址所在的函数
//
// 为什么要自建：Ghidra 自带的脚本没有「给我这几个地址所在的函数」这种模式，
// 而全量反编译（3180 个函数）会产出几十 MB 没人看的东西。对齐工作只需要**按需**取那几个函数。
//
// 用法（analyzeHeadless）：
//   analyzeHeadless <proj> Rich6 -process rich6.exe \
//     -scriptPath "<项目>/tools/ghidra_scripts" \
//     -postScript DecompileAt.java <输出文件> <地址1> <地址2> ...
//
// 地址写 8 位十六进制（如 435f80）。给的是**函数内部地址也能用** ——
// 会用 getFunctionContaining() 找到它所属的那个函数，并额外标出「相对入口的偏移」，
// 这样报告里写的内部地址（如 41f970）也能直接查。
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import java.io.FileWriter;

public class DecompileAt extends GhidraScript {

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 2) {
            println("用法: DecompileAt.java <输出文件> <地址...>");
            return;
        }
        FileWriter w = new FileWriter(args[0], false);
        DecompInterface ifc = new DecompInterface();
        ifc.setOptions(ifc.getOptions());          // 用默认选项
        ifc.openProgram(currentProgram);

        for (int i = 1; i < args.length; i++) {
            String spec = args[i];
            Address a;
            try {
                a = currentProgram.getAddressFactory().getAddress(spec);
            } catch (Exception e) {
                w.write("// ===== " + spec + " → 地址解析失败: " + e.getMessage() + "\n\n");
                continue;
            }
            if (a == null) {
                w.write("// ===== " + spec + " → 地址无效\n\n");
                continue;
            }
            Function f = getFunctionContaining(a);
            if (f == null) {
                w.write("// ===== " + spec + " → 不在任何已知函数内\n\n");
                continue;
            }
            long off = a.getOffset() - f.getEntryPoint().getOffset();
            w.write("// ===== " + spec + " → " + f.getName()
                    + " @ " + f.getEntryPoint()
                    + (off == 0 ? "（就是入口）" : "（入口 +0x" + Long.toHexString(off) + "）")
                    + "  大小 " + f.getBody().getNumAddresses() + " 字节\n");
            DecompileResults r = ifc.decompileFunction(f, 90, monitor);
            if (r != null && r.decompileCompleted()) {
                w.write(r.getDecompiledFunction().getC());
            } else {
                w.write("// 反编译未完成: "
                        + (r == null ? "null" : r.getErrorMessage()) + "\n");
            }
            w.write("\n\n");
        }
        w.close();
        ifc.dispose();
        println("DecompileAt 完成 → " + args[0]);
    }
}
