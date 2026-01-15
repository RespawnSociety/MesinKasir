<?php

namespace App\Http\Controllers\Kasir;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\ProductCategory;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class KasirTransaksiController extends Controller
{
    private function ensureKasirOrAdmin(Request $request): void
    {
        $role = $request->user()->role ?? null;
        if (!in_array($role, ['admin', 'kasir'], true)) {
            abort(Response::HTTP_FORBIDDEN, 'Forbidden (admin/kasir only)');
        }
    }

    public function categories(Request $request)
    {
        $this->ensureKasirOrAdmin($request);

        $data = ProductCategory::query()
            ->where('active', true)
            ->orderBy('name')
            ->get(['id', 'name', 'active']);

        return response()->json([
            'message' => 'OK',
            'data' => $data,
        ]);
    }

    public function products(Request $request)
    {
        $this->ensureKasirOrAdmin($request);

        $q = Product::query()
            ->with(['category:id,name'])
            ->where('active', true)
            ->orderBy('name');

        if ($request->filled('search')) {
            $s = trim((string) $request->input('search'));
            $q->where('name', 'like', "%{$s}%");
        }

        if ($request->filled('category_id')) {
            $q->where('category_id', (int) $request->input('category_id'));
        }

        $perPage = (int) $request->input('per_page', 100);
        $perPage = max(1, min($perPage, 200));

        return response()->json([
            'message' => 'OK',
            'data' => $q->paginate($perPage),
        ]);
    }

    public function productsCount(Request $request)
    {
        $this->ensureKasirOrAdmin($request);

        $q = Product::query()->where('active', true);

        if ($request->filled('search')) {
            $s = trim((string) $request->input('search'));
            $q->where('name', 'like', "%{$s}%");
        }

        if ($request->filled('category_id')) {
            $q->where('category_id', (int) $request->input('category_id'));
        }

        return response()->json([
            'message' => 'OK',
            'data' => [
                'count' => $q->count(),
            ],
        ]);
    }
}
