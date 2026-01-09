<?php

namespace App\Http\Controllers\Product;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Stock;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class StockController extends Controller
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
        $stocks = Stock::query()->orderBy('name')->get();

        return response()->json([
            'message' => 'OK',
            'data' => $stocks,
        ]);
    }

    public function store(Request $request)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:80', 'unique:stocks,name'],
            'active' => ['nullable', 'boolean'],
        ]);

        $stock = Stock::create([
            'name' => $validated['name'],
            'active' => (bool) ($validated['active'] ?? true),
        ]);

        return response()->json([
            'message' => 'Stock created',
            'data' => $stock,
        ], Response::HTTP_CREATED);
    }

    public function update(Request $request, Stock $stock)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:80', 'unique:stocks,name,' . $stock->id],
            'active' => ['sometimes', 'nullable', 'boolean'],
        ]);

        $stock->fill($validated);
        $stock->save();

        return response()->json([
            'message' => 'Stock updated',
            'data' => $stock,
        ]);
    }

    public function destroy(Request $request, Stock $stock)
    {
        $this->ensureAdmin($request);

        $stock->delete();

        return response()->json([
            'message' => 'Stock deleted',
        ]);
    }

    public function productStocks(Request $request, Product $product)
    {
        $data = $product->stocks()
            ->orderBy('name')
            ->get()
            ->map(function ($s) {
                return [
                    'id' => $s->id,
                    'name' => $s->name,
                    'active' => $s->active,
                    'pivot' => [
                        'id' => $s->pivot->id,
                        'qty' => $s->pivot->qty,
                        'active' => $s->pivot->active,
                    ],
                ];
            });

        return response()->json([
            'message' => 'OK',
            'data' => $data,
        ]);
    }

    public function attachToProduct(Request $request, Product $product)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'stock_id' => ['required', 'integer', 'exists:stocks,id'],
            'qty' => ['required', 'integer', 'min:0'],
            'active' => ['nullable', 'boolean'],
        ]);

        $product->stocks()->syncWithoutDetaching([
            (int) $validated['stock_id'] => [
                'qty' => (int) $validated['qty'],
                'active' => (bool) ($validated['active'] ?? true),
            ],
        ]);

        return response()->json([
            'message' => 'Attached',
        ]);
    }

    public function updateProductStock(Request $request, Product $product, Stock $stock)
    {
        $this->ensureAdmin($request);

        $validated = $request->validate([
            'qty' => ['sometimes', 'required', 'integer', 'min:0'],
            'active' => ['sometimes', 'nullable', 'boolean'],
        ]);

        $product->stocks()->updateExistingPivot($stock->id, $validated);

        return response()->json([
            'message' => 'Updated',
        ]);
    }

    public function detachFromProduct(Request $request, Product $product, Stock $stock)
    {
        $this->ensureAdmin($request);

        $product->stocks()->detach($stock->id);

        return response()->json([
            'message' => 'Detached',
        ]);
    }
}
