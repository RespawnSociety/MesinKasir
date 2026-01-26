<?php

namespace App\Http\Controllers\Transaksi;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use App\Models\TransactionHistory;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

use Symfony\Component\HttpFoundation\Response;


class TransactionController extends Controller
{

    private function ensureAdmin(Request $request): void
    {
        $role = $request->user()->role ?? null;
        if ($role !== 'admin') {
            abort(Response::HTTP_FORBIDDEN, 'Forbidden (admin only)');
        }
    }

    public function index(Request $request)
    {
      
       $cashierId = auth()->id(); 

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
}
