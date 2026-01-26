<?php

namespace App\Http\Controllers\Transaksi;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use App\Models\TransactionHistory;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class TransactionController extends Controller
{
    public function index(Request $request)
    {
        $cashierId = auth()->id();
        if (!$cashierId) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $q = Transaction::query()->where('cashier_id', $cashierId);

        if ($request->filled('from')) {
            $q->where('paid_at', '>=', Carbon::parse($request->string('from')));
        }
        if ($request->filled('to')) {
            $q->where('paid_at', '<=', Carbon::parse($request->string('to'))->endOfDay());
        }

        return response()->json([
            'data' => $q->orderByDesc('paid_at')->paginate(20),
        ]);
    }

    public function show(Request $request, $id)
    {
        $cashierId = auth()->id();
        
        if (!$cashierId) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $tx = Transaction::query()
            ->where('cashier_id', $cashierId)
            ->findOrFail($id);

        return response()->json(['data' => $tx]);
    }


    public function history(Request $request)
    {
        $cashierId = auth()->id();
        if (!$cashierId) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $q = TransactionHistory::query()->where('cashier_id', $cashierId);

        if ($request->filled('from')) {
            $q->where('paid_at', '>=', Carbon::parse($request->string('from')));
        }
        if ($request->filled('to')) {
            $q->where('paid_at', '<=', Carbon::parse($request->string('to'))->endOfDay());
        }

        return response()->json([
            'data' => $q->orderByDesc('paid_at')->paginate(20),
        ]);
    }

    public function historyShow(Request $request, $id)
    {
        $cashierId = auth()->id();
        if (!$cashierId) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $tx = TransactionHistory::query()
            ->where('cashier_id', $cashierId)
            ->findOrFail($id);

        return response()->json(['data' => $tx]);
    }

    public function store(Request $request)
    {
        $cashierId = auth()->id();
        if (!$cashierId) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $validated = $request->validate([
            'pay_method' => ['required', Rule::in([1, 2, 3])], // 1 cash, 2 qris, 3 transfer
            'paid_amount' => ['required', 'integer', 'min:0'],
            'items' => ['required', 'array', 'min:1'],

            'items.*.product_id' => ['required', 'integer'],
            'items.*.name' => ['required', 'string'],
            'items.*.qty' => ['required', 'integer', 'min:1'],
            'items.*.unit_price' => ['required', 'integer', 'min:0'],
            'items.*.line_total' => ['required', 'integer', 'min:0'],
        ]);

        $total = 0;
        $items = [];

        foreach ($validated['items'] as $it) {
            $qty = (int) $it['qty'];
            $unit = (int) $it['unit_price'];
            $calc = $qty * $unit;

            $line = (int) $it['line_total'];
            if ($line !== $calc) {
                $line = $calc;
            }

            $total += $line;

            $items[] = [
                'product_id' => (int) $it['product_id'],
                'name' => (string) $it['name'],
                'qty' => $qty,
                'unit_price' => $unit,
                'line_total' => $line,
            ];
        }

        $payMethod = (int) $validated['pay_method'];
        $paid = (int) $validated['paid_amount'];
        $change = 0;

        if ($payMethod === 1) { // cash
            if ($paid < $total) {
                return response()->json(['message' => 'Uang cash kurang'], 422);
            }
            $change = $paid - $total;
        } else {
            $paid = $total;
            $change = 0;
        }

        $tx = DB::transaction(function () use ($cashierId, $items, $payMethod, $total, $paid, $change) {
            return Transaction::create([
                'cashier_id' => $cashierId,
                'items' => $items,
                'pay_method' => $payMethod,
                'total_amount' => $total,
                'paid_amount' => $paid,
                'change_amount' => $change,
                'paid_at' => now(),
            ]);
        });

        return response()->json([
            'message' => 'Transaksi berhasil disimpan',
            'data' => $tx,
        ], 201);
    }
}
