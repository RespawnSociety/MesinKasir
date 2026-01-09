<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\Kasir\KasirController;
use App\Http\Controllers\Pengaturantoko\PengaturantokoController;
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', fn(\Illuminate\Http\Request $r) => $r->user());

    //API UNTUK KASIR
    Route::get('/kasirs', [KasirController::class, 'index']);
    Route::post('/kasirs', [KasirController::class, 'store']);
    Route::patch('/kasirs/{username}/active', [KasirController::class, 'setActive']);
    Route::patch('/kasirs/{username}/pin', [KasirController::class, 'resetPin']);
    Route::delete('/kasirs/{username}', [KasirController::class, 'destroy']);

    //API UNTUK PENGATURAN TOKO
    Route::get('/categories', [PengaturantokoController::class, 'categories']);
    Route::post('/categories', [PengaturantokoController::class, 'createCategory']);
    Route::patch('/categories/{category}/active', [PengaturantokoController::class, 'setCategoryActive']);
    Route::patch('/categories/{category}', [PengaturantokoController::class, 'updateCategory']);
    Route::delete('/categories/{category}', [PengaturantokoController::class, 'deleteCategory']);
});
