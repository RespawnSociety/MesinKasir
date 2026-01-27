<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class StoreSetting extends Model
{
    use HasFactory;

    protected $table = 'store_settings';

    protected $fillable = [
        'store_name',
        'store_address',
        'tax_percent',
    ];

    protected $casts = [
        'tax_percent' => 'float',
    ];
}
