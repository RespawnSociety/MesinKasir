<?php

namespace App\Http\Controllers\Pengaturantoko;

use App\Http\Controllers\Controller;
use App\Models\StoreSetting;
use Illuminate\Http\Request;

class StoreSettingController extends Controller
{
    public function show(Request $request)
    {
        $s = StoreSetting::query()->first();

        if (!$s) {
            $s = StoreSetting::create([
                'store_name' => 'Toko',
                'store_address' => null,
                'tax_percent' => 0,
            ]);
        }

        return response()->json([
            'data' => $s,
        ]);
    }

    public function update(Request $request)
    {
        $validated = $request->validate([
            'store_name' => ['required', 'string', 'min:2', 'max:255'],
            'store_address' => ['nullable', 'string', 'max:2000'],
            'tax_percent' => ['required', 'numeric', 'min:0', 'max:100'],
        ]);

        $s = StoreSetting::query()->first();

        if (!$s) {
            $s = StoreSetting::create($validated);
        } else {
            $s->update($validated);
        }

        return response()->json([
            'message' => 'Store settings updated',
            'data' => $s,
        ]);
    }
}
